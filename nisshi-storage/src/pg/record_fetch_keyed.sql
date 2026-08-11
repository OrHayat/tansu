-- -*- mode: sql; sql-product: postgres; -*-
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

-- prepare record_fetch_keyed (text, text, integer, integer, integer, integer, bytea, integer) as

-- see record_fetch.sql: the row cap has to sit in its own query block so it
-- bounds what the running byte total is computed over.
with bounded as (
select

r.offset_id,
r.attributes,
r.timestamp,
r.k,
r.v,
r.producer_id,
r.producer_epoch,
r.transaction_id

from

cluster c
join topic t on t.cluster = c.id
join topition tp on tp.topic = t.id
join record r on r.topition = tp.id

where

c.name = $1
and t.name = $2
and tp.partition = $3
and r.offset_id >= $4
and r.offset_id < $6
and r.k = convert_to($7, 'UTF-8')

order by r.offset_id
limit $8),

sized as (
select

b.offset_id,
b.attributes,
b.timestamp,
b.k,
b.v,
sum(coalesce(length(b.k), 0) + coalesce(length(b.v), 0)) over (order by b.offset_id) as bytes,
b.producer_id,
b.producer_epoch,
b.transaction_id < pg_snapshot_xmin(pg_current_snapshot())

from bounded b)

select * from sized where bytes < $5 order by offset_id;
