CREATE MATERIALIZED VIEW analytics.average_rating_guild
(
    `guild_id` Int64,
    `rating` AggregateFunction(avgOrNull, Float32)
)
ENGINE = AggregatingMergeTree
ORDER BY guild_id
SETTINGS index_granularity = 8192
AS SELECT
    service_ratings.guild_id AS guild_id,
    avgOrNullState(CAST(service_ratings.rating, 'Float32')) AS rating
FROM tickets.public_service_ratings AS service_ratings
GROUP BY guild_id;

 CREATE MATERIALIZED VIEW analytics.close_reason_counts
(
    `guild_id` Int64,
    `panel_id` Nullable(Int32),
    `close_reason` String,
    `count` AggregateFunction(count, Int64)
)
ENGINE = AggregatingMergeTree
ORDER BY (guild_id, panel_id, close_reason)
SETTINGS allow_nullable_key = 1, index_granularity = 8192
AS SELECT
    public_tickets.guild_id AS guild_id,
    public_tickets.panel_id AS panel_id,
    close_reason.close_reason AS close_reason,
    countState(1) AS count
FROM tickets.public_close_reason AS close_reason
INNER JOIN tickets.public_tickets ON (close_reason.guild_id = public_tickets.guild_id) AND (close_reason.ticket_id = public_tickets.id)
WHERE close_reason.close_reason IS NOT NULL
GROUP BY
    public_tickets.guild_id,
    public_tickets.panel_id,
    close_reason.close_reason
SETTINGS join_algorithm = 'partial_merge';

CREATE MATERIALIZED VIEW analytics.custom_integration_guild_counts
(
    `integration_id` Int64,
    `count` AggregateFunction(count, Int64)
)
ENGINE = AggregatingMergeTree
ORDER BY integration_id
SETTINGS index_granularity = 8192
AS SELECT
    integration_id,
    countState(1) AS count
FROM tickets.public_custom_integration_guilds
GROUP BY integration_id;

CREATE MATERIALIZED VIEW analytics.feedback_count_guild
(
    `guild_id` Int64,
    `count` AggregateFunction(count, Int32)
)
ENGINE = AggregatingMergeTree
ORDER BY guild_id
SETTINGS index_granularity = 8192
AS SELECT
    service_ratings.guild_id AS guild_id,
    countState(1) AS count
FROM tickets.public_service_ratings AS service_ratings
GROUP BY service_ratings.guild_id;

CREATE MATERIALIZED VIEW analytics.first_response_time_guild
(
    `guild_id` Int64,
    `all_time` AggregateFunction(avg, Int64),
    `monthly` AggregateFunction(avgOrNull, Int64),
    `weekly` AggregateFunction(avgOrNull, Int64)
)
ENGINE = AggregatingMergeTree
ORDER BY guild_id
SETTINGS index_granularity = 8192
AS SELECT
    first_response_time_seconds.guild_id AS guild_id,
    avgState(first_response_time_seconds.response_time_seconds) AS all_time,
    avgOrNullStateIf(first_response_time_seconds.response_time_seconds, public_tickets.open_time > (now() - toIntervalDay(30))) AS monthly,
    avgOrNullStateIf(first_response_time_seconds.response_time_seconds, public_tickets.open_time > (now() - toIntervalDay(7))) AS weekly
FROM analytics.first_response_time_seconds
INNER JOIN tickets.public_tickets ON (first_response_time_seconds.guild_id = public_tickets.guild_id) AND (first_response_time_seconds.ticket_id = public_tickets.id)
GROUP BY guild_id;

CREATE MATERIALIZED VIEW analytics.first_response_time_seconds
(
    `guild_id` Int64,
    `ticket_id` Int32,
    `user_id` Int64,
    `response_time_seconds` Int64
)
ENGINE = AggregatingMergeTree
ORDER BY (guild_id, ticket_id)
SETTINGS index_granularity = 8192
AS SELECT
    first_response_time.guild_id AS guild_id,
    first_response_time.ticket_id AS ticket_id,
    first_response_time.user_id AS user_id,
    (simpleJSONExtractInt(first_response_time.response_time, 'seconds') + (simpleJSONExtractInt(first_response_time.response_time, 'minutes') * 60)) + ((simpleJSONExtractInt(first_response_time.response_time, 'hours') * 60) * 60) AS response_time_seconds
FROM tickets.public_first_response_time AS first_response_time;

CREATE MATERIALIZED VIEW analytics.ticket_duration
(
    `guild_id` Int64,
    `all_time` AggregateFunction(avg, Int64),
    `monthly` AggregateFunction(avgOrNull, Int64),
    `weekly` AggregateFunction(avgOrNull, Int64)
)
ENGINE = AggregatingMergeTree
ORDER BY guild_id
SETTINGS index_granularity = 8192
AS SELECT
    guild_id,
    avgStateIf(dateDiff('second', open_time, close_time), close_time IS NOT NULL) AS all_time,
    avgOrNullStateIf(dateDiff('second', open_time, close_time), close_time > (now() - toIntervalDay(30))) AS monthly,
    avgOrNullStateIf(dateDiff('second', open_time, close_time), close_time > (now() - toIntervalDay(7))) AS weekly
FROM tickets.public_tickets AS tickets
WHERE (close_time IS NOT NULL) AND (close_time > toDateTime('2015-01-01 00:00:00'))
GROUP BY guild_id;

CREATE MATERIALIZED VIEW analytics.tickets_per_day
(
    `guild_id` Int64,
    `date` Date,
    `panel_id` Nullable(Int32),
    `count` AggregateFunction(uniqExact, Int32)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(date)
ORDER BY (guild_id, date, panel_id)
SETTINGS allow_nullable_key = 1, index_granularity = 8192
AS SELECT
    public_tickets.guild_id AS guild_id,
    toDate(public_tickets.open_time) AS date,
    public_tickets.panel_id AS panel_id,
    uniqExactState(public_tickets.id) AS count
FROM tickets.public_tickets
GROUP BY
    public_tickets.guild_id,
    toDate(public_tickets.open_time),
    public_tickets.panel_id;

CREATE MATERIALIZED VIEW analytics.top_close_reasons
(
    `guild_id` Int64,
    `panel_id` Nullable(Int32),
    `close_reason` String,
    `ranking` UInt16
)
ENGINE = AggregatingMergeTree
ORDER BY (guild_id, panel_id, ranking)
SETTINGS allow_nullable_key = 1, index_granularity = 8192
AS SELECT
    guild_id,
    panel_id,
    close_reason,
    row_number() OVER (PARTITION BY guild_id, panel_id ORDER BY countMerge(count) DESC) AS ranking
FROM analytics.close_reason_counts
WHERE (close_reason != 'Automatically closed due to inactivity') AND (close_reason != '')
GROUP BY
    guild_id,
    panel_id,
    close_reason;
    
CREATE MATERIALIZED VIEW analytics.total_ticket_count
(
    `guild_id` Int64,
    `count` AggregateFunction(uniqExact, Int32)
)
ENGINE = AggregatingMergeTree
ORDER BY guild_id
SETTINGS index_granularity = 8192
AS SELECT
    tickets.guild_id AS guild_id,
    uniqExactState(tickets.id) AS count
FROM tickets.public_tickets AS tickets
GROUP BY tickets.guild_id;