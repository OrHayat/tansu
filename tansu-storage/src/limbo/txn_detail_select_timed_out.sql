-- -*- mode: sql; sql-product: sqlite; -*-
-- Copyright ⓒ 2024-2026 Peter Morgan <peter.james.morgan@gmail.com>
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- Select transactions still in BEGIN whose timer has expired.
--
-- A transaction's timer starts when its first partition is added
-- (txn_detail.started_at). It is timed out once
-- started_at + transaction_timeout_ms is earlier than now. The
-- comparison is done in SQL so it uses the same clock as started_at
-- (the DB current_timestamp).
--
-- started_at and current_timestamp are each converted to whole unix epoch
-- seconds (strftime('%s', t)) and scaled to milliseconds, then
-- started_at + transaction_timeout_ms is compared against now. The epoch
-- form is used rather than a datetime() modifier because limbo's datetime()
-- rejects a fractional '+N.M seconds' modifier (it returns an empty string),
-- which a sub-second transaction_timeout_ms would otherwise need.
--
-- current_timestamp has whole-second resolution, so started_at (written from
-- it) carries no fractional part; the millisecond resolution that matters is
-- on transaction_timeout_ms, which is added directly in milliseconds. This is
-- plain SQLite that libSQL accepts too.
--
-- transaction_timeout_ms of 0 means "no timeout" and is skipped.
--
-- The columns returned mirror the identifiers that txn_end accepts:
-- (transaction_id, producer_id, producer_epoch).

select txn.name, p.id, pe.epoch

from

cluster c
join txn on txn.cluster = c.id
join producer p on p.cluster = c.id and txn.producer = p.id
join producer_epoch pe on pe.producer = p.id
join txn_detail txn_d on txn_d."transaction" = txn.id and txn_d.producer_epoch = pe.id

where

c.name = $1
and txn_d.status = 'BEGIN'
and txn_d.transaction_timeout_ms > 0
and txn_d.started_at is not null
and strftime('%s', txn_d.started_at) * 1000 + txn_d.transaction_timeout_ms
    < strftime('%s', current_timestamp) * 1000;
