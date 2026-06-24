-- -*- mode: sql; sql-product: sqlite; -*-
-- Copyright ⓒ 2024-2025 Peter Morgan <peter.james.morgan@gmail.com>
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

-- prepare txn_detail_select_timed_out (text) as

-- Find transactions still in BEGIN whose timeout has elapsed, so that
-- maintain() can abort them. A transaction_timeout_ms of 0 means "no
-- timeout" and is skipped. started_at is stored as a DB current_timestamp
-- (whole-second resolution); the deadline is started_at plus
-- transaction_timeout_ms, computed in Julian days: julianday(started_at) plus
-- the timeout converted from milliseconds to days (transaction_timeout_ms /
-- 86400000.0, where 86400000 ms = 1 day). The julianday form carries the
-- millisecond precision of transaction_timeout_ms, so a sub-second timeout is
-- honored even though started_at itself is whole-second. Returns the
-- (transaction_id, producer_id, producer_epoch) tuple that txn_end accepts.

select

txn.name as transaction_id,
p.id as producer_id,
pe.epoch as producer_epoch

from

cluster c
join producer p on p.cluster = c.id
join producer_epoch pe on pe.producer = p.id
join txn on txn.cluster = c.id and txn.producer = p.id
join txn_detail txn_d on txn_d."transaction" = txn.id and txn_d.producer_epoch = pe.id

where

c.name = $1
and txn_d.status = 'BEGIN'
and txn_d.started_at is not null
and txn_d.transaction_timeout_ms > 0
and julianday(txn_d.started_at) + (txn_d.transaction_timeout_ms / 86400000.0) < julianday(current_timestamp);
