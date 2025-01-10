# Self Hosting Tickets Bot

This is a guide to self host the [Tickets bot](https://discord.com/users/508391840525975553). Which was [announced to sunset on the 5th of March 2025](https://discord.com/channels/508392876359680000/508410703439462400/1325516916995129445). This guide will help you set up the bot on your own machine using Docker. **This is not an official guide and I will not provide support.**

## Pre-requisites

- You must have knowledge of how to use, deploy and run containers (specifically Docker)
- You must have an idea of how to use a terminal
- You should have a basic understanding of GoLang, Rust, and Svelte
- You should have a basic understanding of how to use a database (specifically PostgreSQL)

## How does the bot work?

To be completely honest, I still don't know. The image below is a rough diagram of how I think the bot works after nearly a week of tinkering with the TicketsBot codebase.

![Excalidraw](./ticketsbot-2025-01-10T08_15_41_704Z.svg)

## Setup (Simple)

1. Open a terminal in the folder you want to install the bot in. (Or create a folder and open a terminal in that folder)
2. Clone this repository into that folder (`git clone https://github.com/DanPlayz0/ticketsbot-self-host-guide.git .`) 
    - The `.` at the end is important as it clones the repository into the current folder)
3. Replace the placeholders in the `docker-compose.yaml` file. (The e.g. values are examples, do not use them)
    - Replace `${DISCORD_BOT_TOKEN}` with your bot token (e.g. `OTAyMzYyNTAxMDg4NDM2MjI0.YXdUkQ.TqZm7gNV2juZHXIvLdSvaAHKQCzLxgu9`)
    - Replace `${DISCORD_BOT_CLIENT_ID}` with your bot's client ID (e.g. `508391840525975553`)
    - Replace `${DISCORD_BOT_OAUTH_SECRET}` with your bot's client secret (e.g. `AAlRmln88YpOr8H8j1VvFuidKLJxg9rM`)
    - Replace `${DISCORD_BOT_PUBLIC_KEY}` with your bot's public key (e.g. `fcd10216ebbc818d7ef1408a5c3c5702225b929b53b0a265b82e82b96a9a8358`)
    - Replace `${DISCORD_SUPPORT_SERVER_INVITE}` with the invite link to your support server (e.g. `https://discord.gg/VtV3rSk`)
    - Replace `${SENTRY_DSN}` with your Sentry DSN
    - Replace `${LANDING_PAGE_URL}` with the URL of your landing page (it should have a `/premium` page) (e.g. `https://ticketsbot.net`)
    - Replace `${DASHBOARD_URL}` with the URL of your API (e.g. `http://localhost:8082`, you can use localhost but it's recommended to be a public URL)
    - Replace `${API_URL}` with the URL of your API (e.g. `http://localhost:5000`, you can use localhost but it's recommended to be a public URL)
    - Replace `${JWT_SECRET}` with a random string (e.g. `randomstring`)
    - Replace `${ADMIN_USER_IDS}` with a comma-separated list of user IDs (e.g. `209796601357533184,585576154958921739,user_id,user_id`, a single id would be `209796601357533184`)
    - Replace `${ARCHIVER_ADMIN_AUTH_TOKEN}` with a random string (e.g. `randomstring`)
    - Replace `${S3_ENDPOINT}` with the endpoint of your S3 bucket (e.g. `minio:9000`, no `https://`)
    - Replace `${S3_ACCESS}` with the access key of your S3 bucket (e.g. `AbCdEfFgHiJkLmNoPqRsTuVwXyZ`)
    - Replace `${S3_SECRET}` with the secret key of your S3 bucket (e.g. `AbCdEfFgHiJkLmNoPqRsTuVwXyZ`)
    - Replace `${ARCHIVER_AES_KEY}` with a AES-128 key (aka 16 bytes), you can generate one one of the following commands: 
        - Bash: `openssl rand -hex 16`
        - NodeJS: `node -e "console.log(require('crypto').randomBytes(16).toString('hex'))"`
4. Replace the placeholders in the following command and paste it at the bottom of `init-archive.sql`. There are 2 placeholders in the command, `${BUCKET_NAME}` and `${S3_ENDPOINT}`. Replace them with your bucket name and S3 endpoint respectively. You can also just edit the `init-archive.sql` file too, you just have to uncomment it (by removing the `--` at the start of the line) and replace variables there.
    ```sql
    INSERT INTO buckets (id, endpoint_url, name, active) VALUES ('b77cc1a0-91ec-4d64-bb6d-21717737ea3c', 'https://${S3_ENDPOINT}', '${BUCKET_NAME}', TRUE);
    ```
5. Run `docker compose up -d` to pull the images and start the bot.
6. Configure the Discord bot. ([see below](#discord-bot-configuration))
7. Register the slash commands ([see below](#registering-the-slash-commands-using-docker-recommended))

## Discord Bot Configuration

As this bot is self-hosted, you will need to configure the bot yourself. Here are the steps to configure the bot:

1. Go to the [Discord Developer Portal](https://discord.com/developers/applications)
2. Click on the application you created for the bot
3. Set the `Interactions Endpoint URL` to `${HTTP_GATEWAY}/handle/${DISCORD_BOT_CLIENT_ID}`
    - Replace `${HTTP_GATEWAY}` with the URL of your HTTP Gateway (e.g. `http://localhost:8080`, you must have a publicly accessible URL not localhost)
    - Replace `${DISCORD_BOT_CLIENT_ID}` with your bot's application/client ID (e.g. `508391840525975553`)
4. Go to the OAuth2 tab
5. Add the redirect URL `${API_URL}/callback` to the OAuth2 redirect URIs
    - Replace `${API_URL}` with the URL of your API (e.g. `http://localhost:8080`, make sure this matches what you set in the [Setup](#setup-simple) section)

## Setup (Complex)

1. Create a folder somewhere (it will be where the bot will be installed), and open a terminal in that folder.
2. Download the `schema.sql` (postgres dump file) from [#self-hosting](https://discord.com/channels/508392876359680000/1325513300892581898) channel in the [Tickets Support Discord server](https://discord.gg/NHz6G3qv55).
    - Rename `schema.sql` to `init.sql`.
    - Add the following lines to the top of `init.sql` dump file:
      ```sql
      -- Create the roles 
      CREATE ROLE backup;
      CREATE ROLE clickhouse;
      CREATE ROLE peerdb;
      CREATE ROLE tickets;
      CREATE ROLE votelistener;
      ```
    - Move it to the root of the folder you created.
3. Download [`0001-init-schema.sql`](https://github.com/TicketsBot/logarchiver/blob/master/migrations/0001-init-schema.sql) and rename it to `init-archive.sql`.
4. Create a `init-cache.sql` and copy the SQL lines
    - For those being lazy, here's the SQL lines: 
      ```sql
      -- Downloaded from https://github.com/rxdn/gdl/blob/master/cache/pgcache.go#L122-L138 (only include the SQL lines, not the GoLang code (aka batch.Queue))
      CREATE TABLE IF NOT EXISTS guilds("guild_id" int8 NOT NULL UNIQUE, "data" jsonb NOT NULL, PRIMARY KEY("guild_id"));
      CREATE TABLE IF NOT EXISTS channels("channel_id" int8 NOT NULL UNIQUE, "guild_id" int8 NOT NULL, "data" jsonb NOT NULL, PRIMARY KEY("channel_id", "guild_id"));
      CREATE TABLE IF NOT EXISTS users("user_id" int8 NOT NULL UNIQUE, "data" jsonb NOT NULL, PRIMARY KEY("user_id"));
      CREATE TABLE IF NOT EXISTS members("guild_id" int8 NOT NULL, "user_id" int8 NOT NULL, "data" jsonb NOT NULL, PRIMARY KEY("guild_id", "user_id"));
      CREATE TABLE IF NOT EXISTS roles("role_id" int8 NOT NULL UNIQUE, "guild_id" int8 NOT NULL, "data" jsonb NOT NULL, PRIMARY KEY("role_id", "guild_id"));
      CREATE TABLE IF NOT EXISTS emojis("emoji_id" int8 NOT NULL UNIQUE, "guild_id" int8 NOT NULL, "data" jsonb NOT NULL, PRIMARY KEY("emoji_id", "guild_id"));
      CREATE TABLE IF NOT EXISTS voice_states("guild_id" int8 NOT NULL, "user_id" INT8 NOT NULL, "data" jsonb NOT NULL, PRIMARY KEY("guild_id", "user_id"));
      -- create index
      CREATE INDEX CONCURRENTLY IF NOT EXISTS channels_guild_id ON channels("guild_id");
      CREATE INDEX CONCURRENTLY IF NOT EXISTS members_guild_id ON members("guild_id");
      CREATE INDEX CONCURRENTLY IF NOT EXISTS member_user_id ON members("user_id");
      CREATE INDEX CONCURRENTLY IF NOT EXISTS roles_guild_id ON roles("guild_id");
      CREATE INDEX CONCURRENTLY IF NOT EXISTS emojis_guild_id ON emojis("guild_id");
      CREATE INDEX CONCURRENTLY IF NOT EXISTS voice_states_guild_id ON voice_states("guild_id");
      CREATE INDEX CONCURRENTLY IF NOT EXISTS voice_states_user_id ON voice_states("user_id");
      ```
5. Create the `dashboard.Dockerfile` and copy the following code block (this compiles the Svelte frontend with your bot's client ID, API URL and Websocket URL)
    ```dockerfile
    FROM node:lts-alpine AS build

    # Install packages
    USER root
    RUN apk add --no-cache git

    # Create the directory!
    RUN mkdir -p /tmp && chown -R node:node /tmp
    WORKDIR /tmp
    USER node

    # Clone the repository to /tmp
    RUN git clone https://github.com/TicketsBot/dashboard.git /tmp

    # Switch directories to the frontend
    WORKDIR /tmp/frontend

    # Install node_modules (including development/build)
    RUN npm install

    # Build the frontend (and include the env variables required during buildtime)
    ARG CLIENT_ID
    ARG REDIRECT_URI
    ARG API_URL
    ARG WS_URL

    RUN npm run build

    # Remove development node_modules
    RUN npm prune --production


    # Production container
    FROM node:lts-alpine AS prod

    RUN mkdir -p /app && chown -R node:node /app
    WORKDIR /app
    USER node

    COPY --from=build --chown=node:node /tmp/frontend/package*.json /app/
    COPY --from=build --chown=node:node /tmp/frontend/node_modules /app/node_modules
    COPY --from=build --chown=node:node /tmp/frontend/public /app/public

    ENV NODE_ENV=production
    CMD ["npm", "run", "start"]
    ```
6. Download the `docker-compose.yaml`

## Registering the slash commands using Docker (Recommended)

1. Create the `commands.Dockerfile` and copy the following code block (this registers the commands with the bot)
    ```dockerfile
    # Build container
    FROM golang:1.22 AS builder

    RUN go version

    RUN apt-get update && apt-get upgrade -y && apt-get install -y ca-certificates git zlib1g-dev

    WORKDIR /go/src/github.com/TicketsBot
    RUN git clone https://github.com/TicketsBot/worker.git
    WORKDIR /go/src/github.com/TicketsBot/worker

    RUN git submodule update --init --recursive --remote

    RUN set -Eeux && \
        go mod download && \
        go mod verify

    RUN GOOS=linux GOARCH=amd64 \
        go build \
        -tags=jsoniter \
        -trimpath \
        -o main cmd/registercommands/main.go

    # Executable container
    FROM ubuntu:latest

    RUN apt-get update && apt-get upgrade -y && apt-get install -y ca-certificates curl

    COPY --from=builder /go/src/github.com/TicketsBot/worker/locale /srv/worker/locale
    COPY --from=builder /go/src/github.com/TicketsBot/worker/main /srv/worker/main

    RUN chmod +x /srv/worker/main

    RUN useradd -m container
    USER container
    WORKDIR /srv/worker

    ENTRYPOINT ["/srv/worker/main"]
    ```
2. Build the register commands cli utility using `docker build -t ticketsbot/registercommands -f commands.Dockerfile .`
3. Get help by running `docker run --rm ticketsbot/registercommands --help`
4. Register the commands 
    - Global commands only: `docker run --rm ticketsbot/registercommands --token=your_bot_token --id=your_client_id`
    - Global & Admin commands by running `docker run --rm ticketsbot/registercommands --token=your_bot_token --id=your_client_id --admin-guild=your_admin_guild_id`

## Registering the slash commands using GoLang

1. Clone the [worker repository](https://github.com/TicketsBot/worker) (`git clone https://github.com/TicketsBot/worker.git`)
2. Change directory to the `worker` folder (`cd worker`)
3. Run `go run cmd/registercommands/main.go --token=your_bot_token --id=your_client_id`
    - If you want to register the admin commands, add `--admin-guild=your_admin_guild_id` to the command

4. If you get errors related to zlib (`undefined: Zstream`, `undefined: NewZstream`, `undefined: zNoFlush`, `undefined: zSyncFlush`, etc)
    - You are missing the zlib package and [GDL](https://github.com/rxdn/gdl/) uses it.
    - You can install it by running one of the following (depending on your package manager)
      - Ubuntu: `apt-get install zlib1g-dev`
      - CentOS: `yum install zlib-devel`

## Frequently Asked Questions

1. What can I host this on?
    - You should be able to host this on any machine that can run Docker containers
  
2. What are the system requirements?
    - I cannot recommend any specific requirements, but I can give you some information on the resources used by the bot (CPU metrics are out of 1200% as i was using a 6 core CPU with 12 logical processors):
        - Starting up the bot the peak was around 475.44MB of RAM and 43.21% CPU. (This was on a fresh start, it may vary)
        - After using the bot for a while, the bot was using around 1.5GB of RAM and 18% of a CPU.

3. Can I turn off the logging?
    - Kinda of, in certain containers there are environment variables such as the following which you can remove: 
      ```yaml
      RUST_BACKTRACE: 1
      RUST_LOG: trace
      ```
4. How do I update the bot?
    - The docker compose uses a specific hash for the bot's containers, so you will have to manually find the new hash and update the `docker-compose.yaml` file.
5. How do I get rid of the `ticketsbot.net` branding?
    - If you have knowledge of how to compile GoLang, Rust, and Svelte, you can change the branding in the bot's [source code](https://github.com/TicketsBot) and recompile the bot and update those container hashes in `docker-compose.yaml` file and then re-run the bot.