# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Bear Blog is a Django 5.2 multi-tenant blogging platform (similar to Substack, not self-hostable). Users create blogs at subdomains (e.g., `user.bearblog.dev`) or custom domains. The platform emphasizes simplicity: no JavaScript, no trackers, minimal CSS.

## Development Commands

```bash
make dev              # Run dev server on localhost:1414
make migrate          # Run database migrations
make makemigrations   # Create new migration files
make shell            # Django shell on Heroku
make logs             # Tail Heroku logs (filtered)
```

## Architecture

### Multi-Tenancy & Domain Resolution

The platform resolves which blog to serve via `blogs/views/blog.py`:
1. Check if request host is in `MAIN_SITE_HOSTS` → serve homepage
2. Extract subdomain from host → lookup Blog by subdomain
3. Otherwise → lookup Blog by custom domain (cached in Redis)

Custom domains use a Caddy reverse proxy on DigitalOcean with on-demand TLS certificates.

### Core Models (`blogs/models.py`)

- **UserSettings**: One-to-one with User; tracks subscription status, max blogs
- **Blog**: The tenant; has subdomain, optional custom domain, content, styling, moderation flags
- **Post**: Blog content; supports Markdown, tags (JSON), discovery feed score calculation
- **Hit**: Server-side analytics (no client JS); tracks referrer, country (GeoIP), device, browser
- **Upvote**: Vote tracking for discovery feed ranking
- **Subscriber**: Email newsletter subscriptions
- **PersistentStore**: Singleton for global settings (spam terms, reviewed blogs)

### View Organization (`blogs/views/`)

- `blog.py` - Public blog rendering, domain resolution, post serving
- `studio.py` - Post/blog creation and editing
- `dashboard.py` - User blog management
- `analytics.py` - Analytics display
- `discover.py` - Discovery feed
- `emailer.py` - Email subscriptions
- `feed.py` - RSS/Atom generation
- `media.py` - Image uploads (to DigitalOcean Spaces)
- `staff.py` - Admin moderation tools
- `signup_flow.py` - Registration

### Middleware Stack (`blogs/middleware.py`)

Key custom middleware:
- **RateLimitMiddleware**: 10 req/10s limit, 60s ban (100 req/10s in dev)
- **BotWallMiddleware**: Shows botwall if no timezone cookie
- **AllowAnyDomainCsrfMiddleware**: CSRF handling for custom domains

### Discovery Feed Scoring

Posts are ranked by: `log10(upvotes) + (timestamp - epoch) / (buoyancy * 86400)`
- Upvotes capped at 30 to prevent eternal ranking
- Buoyancy = 14 days (controls time decay)
- Blogs have a `dodginess_score` for spam detection

## Key Technical Details

- **Database**: SQLite (`dev.db`) in dev, PostgreSQL in production
- **Caching**: Redis (if `REDISCLOUD_TLS_URL` set), domain→blog mapping cached 1 hour
- **Static files**: WhiteNoise with compression
- **Email**: Mailgun SMTP, async via `EmailThread`
- **Images**: Uploaded to DigitalOcean Spaces S3
- **Auth**: django-allauth, email-only login

## Environment Variables

Required in production:
- `SECRET` - Django secret key
- `DATABASE_URL` - PostgreSQL connection
- `REDISCLOUD_URL` - Redis connection
- `SENTRY_DSN` - Error tracking
- `MAILGUN_PASSWORD` - Email service
- `CLOUDFLARE_API_KEY`, `CLOUDFLARE_EMAIL`, `CLOUDFLARE_ZONE_ID` - Cache invalidation
- `MAIN_SITE_HOSTS` - Comma-separated main domains
- `ENVIRONMENT` - 'dev' for development mode

## Deployment

- **Production**: Heroku with gunicorn, auto-migrations on release
- **Staging**: DigitalOcean droplet with Caddy, SQLite, Litestream backups
