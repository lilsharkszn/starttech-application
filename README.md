# StartTech Application

Full-stack Todo application with a React frontend and Golang backend, deployed on AWS with automated CI/CD via GitHub Actions.

## Table of Contents
- [Application Overview](#application-overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [CI/CD Pipelines](#cicd-pipelines)
- [Deployment Scripts](#deployment-scripts)
- [Environment Variables](#environment-variables)
- [API Reference](#api-reference)

---

## Application Overview

| Layer | Technology | Hosting |
|---|---|---|
| Frontend | React 18, TypeScript, Vite, TanStack Router | AWS S3 + CloudFront |
| Backend API | Go 1.23, Gin framework | EC2 (ASG) behind ALB |
| Cache | Redis 7.0 (username cache, sessions) | AWS ElastiCache |
| Database | MongoDB | MongoDB Atlas |

---

## Repository Structure

starttech-application/ ├── .github/ │ └── workflows/ │ ├── backend-ci-cd.yml # Go test → Docker build → ECR push → ASG deploy │ └── frontend-ci-cd.yml # npm build → S3 sync → CloudFront invalidation ├── Client/ # React frontend (Vite + TypeScript) │ ├── src/ │ │ ├── routes/ # TanStack Router pages │ │ ├── components/ # Reusable UI components (shadcn/ui) │ │ ├── context/ # Auth context │ │ ├── hooks/ # Custom hooks │ │ ├── lib/ # API client, utilities │ │ └── types/ # TypeScript type definitions │ ├── package.json │ └── vite.config.ts ├── Server/ │ └── MuchToDo/ # Golang backend │ ├── cmd/api/main.go # Application entrypoint │ ├── internal/ │ │ ├── auth/ # JWT token service │ │ ├── cache/ # Redis cache service │ │ ├── config/ # Environment config loader │ │ ├── database/ # MongoDB connection │ │ ├── handlers/ # HTTP request handlers │ │ ├── middleware/ # Auth, CORS, logging middleware │ │ ├── models/ # MongoDB data models │ │ ├── routes/ # Route registration │ │ └── utils/ # Cookie utilities │ ├── Dockerfile # Multi-stage Docker build │ └── go.mod ├── scripts/ │ ├── deploy-backend.sh # Manual backend deployment │ ├── deploy-frontend.sh # Manual frontend deployment │ ├── health-check.sh # Backend health validation │ └── rollback.sh # Backend rollback to previous image └── README.md


---

## Prerequisites

### For local development
- [Go 1.23+](https://go.dev/dl/)
- [Node.js 20+](https://nodejs.org/)
- [Docker](https://docs.docker.com/get-docker/)
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

### For deployment
- AWS credentials with ECR push + S3 access
- Access to the starttech-infra Terraform outputs

---

## Local Development

### Backend

```bash
cd Server/MuchToDo

# Create environment file
cat > .env << ENV
PORT=8080
MONGO_URI=mongodb://localhost:27017
DB_NAME=much_todo_db
JWT_SECRET_KEY=$(openssl rand -hex 32)
REDIS_ADDR=localhost:6379
REDIS_PASSWORD=
ENABLE_CACHE=true
LOG_LEVEL=debug
LOG_FORMAT=text
ENV

# Start local dependencies (MongoDB + Redis)
docker-compose up -d

# Run the application
go run ./cmd/api/main.go

API available at: http://localhost:8080 Swagger docs at: http://localhost:8080/swagger/index.html
Frontend
Bash

cd Client

# Install dependencies
npm ci

# Create environment file
cat > .env.local << ENV
VITE_API_BASE_URL=http://localhost:8080
ENV

# Start development server
npm run dev

Frontend available at: http://localhost:5173
Run Tests
Bash

# Backend unit tests
cd Server/MuchToDo
go test ./...

# Backend tests with race detection and coverage
go test -race -coverprofile=coverage.out ./...

# Backend integration tests (requires Docker)
INTEGRATION=true go test -v --tags=integration ./...

# Frontend (if test suite added)
cd Client
npm test

CI/CD Pipelines
Backend Pipeline — .github/workflows/backend-ci-cd.yml
Triggered on push/PR to main when files in Server/ change.

Push to main (Server/** changed)
          │
          ▼
    ┌─────────────────────┐
    │  test               │
    │  ─────────────────  │
    │  • go mod download  │
    │  • go vet           │
    │  • go test -race    │
    │  • govulncheck      │
    └──────────┬──────────┘
               │ (main branch only)
               ▼
    ┌─────────────────────┐
    │  build              │
    │  ─────────────────  │
    │  • ECR login        │
    │  • docker build     │
    │  • trivy scan       │
    │  • push :sha + :latest│
    └──────────┬──────────┘
               │
               ▼
    ┌─────────────────────┐
    │  deploy             │
    │  ─────────────────  │ ← Manual approval gate
    │  • ASG instance     │
    │    refresh          │
    │  • Wait for healthy │
    │  • Smoke tests      │
    └─────────────────────┘

Frontend Pipeline — .github/workflows/frontend-ci-cd.yml
Triggered on push/PR to main when files in Client/ change.

Push to main (Client/** changed)
          │
          ▼
    ┌─────────────────────┐
    │  build              │
    │  ─────────────────  │
    │  • npm ci           │
    │  • npm audit        │
    │  • npm run build    │
    │  • verify dist/     │
    └──────────┬──────────┘
               │ (main branch only)
               ▼
    ┌─────────────────────┐
    │  deploy             │
    │  ─────────────────  │ ← Manual approval gate
    │  • S3 sync HTML     │   (no-cache headers)
    │  • S3 sync assets   │   (immutable headers)
    │  • CF invalidation  │
    └─────────────────────┘

Required GitHub Secrets (App Repo)
SecretDescription
AWS_ACCESS_KEY_IDAWS IAM access key
AWS_SECRET_ACCESS_KEYAWS IAM secret key
ECR_REPOSITORY_URLFull ECR repository URL
S3_BUCKET_NAMEFrontend S3 bucket name
ALB_DNS_NAMEBackend ALB DNS name
CLOUDFRONT_DISTRIBUTION_IDCloudFront distribution ID (when enabled)


Deployment Scripts
All scripts are in scripts/. Make them executable with:

Bash
# Deploy latest image
./scripts/deploy-backend.sh

# Deploy specific image tag
./scripts/deploy-backend.sh a1b2c3d4

deploy-frontend.sh
Bash

# Build first
cd Client && npm ci && npm run build && cd ..

# Deploy to S3
./scripts/deploy-frontend.sh <bucket-name>

# Deploy + invalidate CloudFront
./scripts/deploy-frontend.sh <bucket-name> <distribution-id>

health-check.sh
Bash

# Check backend health (5 retries by default)
./scripts/health-check.sh dev-backend-alb-2008053916.us-east-1.elb.amazonaws.com

# Custom retry count
./scripts/health-check.sh <alb-dns> 10

rollback.sh
Bash

# List available tags first
aws ecr list-images --repository-name dev-starttech-backend \
  --filter tagStatus=TAGGED \
  --query "imageIds[*].imageTag" --output table

# Rollback to a specific tag
./scripts/rollback.sh a1b2c3d4

nvironment Variables
Backend .env
VariableDescriptionExample
PORTServer listen port8080
MONGO_URIMongoDB connection stringmongodb+srv://...
DB_NAMEMongoDB database namemuch_todo_db
JWT_SECRET_KEYJWT signing secret (min 32 chars)$(openssl rand -hex 32)
REDIS_ADDRRedis host:portlocalhost:6379
REDIS_PASSWORDRedis password (empty if none)``
ENABLE_CACHEToggle Redis cachingtrue
LOG_LEVELLog levelinfo
LOG_FORMATLog format (json or text)json
Frontend .env.local
VariableDescriptionExample
VITE_API_BASE_URLBackend API base URLhttp://localhost:8080
API Reference
Full interactive documentation available at /swagger/index.html when running locally.
Key Endpoints
MethodPathAuthDescription
GET/pingNoHealth check
GET/healthNoDetailed health status
POST/api/users/registerNoRegister new user
POST/api/users/loginNoLogin, returns JWT cookie
POST/api/users/logoutYesLogout
GET/api/users/meYesGet current user profile
GET/api/todosYesList user's todos
POST/api/todosYesCreate new todo
PUT/api/todos/:idYesUpdate todo
DELETE/api/todos/:idYesDelete todo
