# GenAI Service Decisions & Justifications

## Executive Summary

This document captures the rationale for service selections in the Wind Farm GenAI/Bedrock pipeline. Each choice balances functionality, cost, latency, and operational complexity for a production wind farm intelligence platform.

---

## Decision Matrix

### 1. Foundation Model (LLM) Selection

**Decision: Amazon Bedrock with Claude 3 Sonnet (or Haiku for latency-sensitive workloads)**

**Alternatives Considered:**
- Self-hosted LLM (Llama 2, Mistral) on SageMaker or EC2
- OpenAI API (GPT-4, GPT-3.5-turbo)
- Anthropic Direct API
- Fine-tuned custom model

**Justification:**

| Factor | Claude 3 (Bedrock) | Self-Hosted | OpenAI API | Fine-Tuned |
|--------|-------------------|-------------|-----------|-----------|
| **Cost/1K tokens** | $0.003 (Haiku), $0.015 (Sonnet) | Variable (instance cost) | $0.015 (3.5), $0.03 (4) | $0.00015 (inference) |
| **Latency** | ~2–4 sec | ~1–3 sec (warm) | ~2–5 sec | ~1–3 sec (warm) |
| **Domain Accuracy** | Baseline (needs RAG) | Baseline | Baseline | +20–40% (with quality data) |
| **Multimodal** | Yes (vision models coming) | Yes (if using multimodal) | Yes | Optional |
| **Security/Compliance** | AWS-managed, SOC2, ISO | Self-managed | Third-party | AWS-managed |
| **Operational Overhead** | Minimal | High | Minimal | High (training/versioning) |
| **Cold Start** | N/A (managed) | Minutes (instance spin) | N/A | N/A |
| **No. of Calls/Month** | 100k calls = $1.50 (Haiku) | 100k calls = $20–50 | 100k calls = $1.50–3 | N/A |

**Rationale:**
- **Bedrock** chosen for **managed operations** (no infrastructure to maintain), **built-in security**, and **low cost at small/medium scale**.
- **Claude 3** for **strong reasoning** (multi-step wind farm queries), **reduced hallucination**, and **native tool use support**.
- **Haiku** for **lower-latency dashboard interactions** (~2 sec); **Sonnet** for **complex reasoning** (multi-turbine scenario analysis).
- Self-hosted rejected: operational complexity outweighs modest latency gains at this scale.
- Fine-tuned model reserved for **Phase 2** if domain-specific accuracy becomes critical (e.g., wind power predictions, maintenance predictions).

**Cost Analysis (100 queries/day):**
- Bedrock Haiku: ~$45/month (assuming 3k tokens per query average).
- Self-hosted (ml.g4dn.xlarge): ~$600/month + engineer time.
- **Winner: Bedrock** (~13x cheaper).

**Decision Record:** ✅ **APPROVED** — Use Claude 3 (Haiku for chat, Sonnet for analysis); revisit fine-tuning in Q2 2026 if accuracy gaps emerge.

---

### 2. Orchestration & Multi-Step Workflow

**Decision: Bedrock Agents (native tool use)**

**Alternatives Considered:**
- Custom orchestration (LangChain/LlamaIndex on Lambda)
- AWS Step Functions + Lambda
- Self-hosted agent framework (AutoGPT, AgentGPT)
- Langchain Agents on SageMaker

**Justification:**

| Factor | Bedrock Agents | Step Functions + Lambda | LangChain on Lambda | Self-Hosted |
|--------|----------------|------------------------|---------------------|------------|
| **Setup Time** | ~2 weeks | ~1 week | ~2 weeks | ~3–4 weeks |
| **Action Flexibility** | High (OpenAPI-based) | High (AWS-native) | High | High |
| **Error Handling** | Built-in retries | Built-in retries | Manual | Manual |
| **Cost/1K Invocations** | ~$5 (Bedrock) + $0.02 (Lambda) | ~$0.02 (Step Functions) + Lambda | ~$0.02 (Lambda) | N/A |
| **Execution Time** | ~10–30 sec (agent loop) | ~5–10 sec | ~10–30 sec | ~10–30 sec |
| **Monitoring** | CloudWatch + Bedrock API logs | CloudWatch + Step Fn logs | CloudWatch | Custom |
| **Prompt Management** | Bedrock console + Terraform | N/A | Code-based | Code-based |

**Rationale:**
- **Bedrock Agents** chosen for **native integration** with LLM, **automatic retry logic**, and **tool composition** without boilerplate.
- **Step Functions** rejected: requires Lambda for each step; higher operational overhead for typical RAG workflows.
- **LangChain** on Lambda: valid alternative but introduces OSS dependency; Bedrock Agents are AWS-native and have stronger SLAs.
- **Self-hosted**: too much engineering effort for MVP; risks around reliability and scalability.

**Tool Invocation Flow:**
```
Query → Agent (Claude 3) → Evaluates KB + Tool Options → Selects Actions
  → Invoke Lambda 1 (QueryWindData) → Return results
  → Invoke Lambda 2 (PredictPower) → Return predictions
  → Synthesize response → Return to user
```

**Cost Analysis (1000 agent queries/month):**
- Bedrock Agents: ~$5 (Bedrock compute) + $0.02 (Lambda overhead) = **$5.02/month**.
- Step Functions: ~$0.02 (Step Fn) + variable Lambda = **$1–5/month** (cheaper for simple flows, but loses LLM reasoning).
- **Winner: Bedrock Agents** (adds reasoning; minor cost premium justified).

**Decision Record:** ✅ **APPROVED** — Use Bedrock Agents; implement retry logic and error handling in Lambda action groups.

---

### 3. Knowledge Base & Vector Search

**Decision: Bedrock Knowledge Base (managed vector indexing) + PostGIS for spatial queries**

**Alternatives Considered:**
- Self-hosted Weaviate/Pinecone/Milvus
- OpenSearch with k-NN
- pgvector only (PostgreSQL vector extension)
- Hybrid: Bedrock KB + separate vector DB

**Justification:**

| Factor | Bedrock KB | Weaviate/Pinecone | OpenSearch k-NN | pgvector Only |
|--------|-----------|------------------|-----------------|--------------|
| **Setup Time** | ~1 week | ~2 weeks | ~2 weeks | Minimal (add to RDS) |
| **Indexing Latency** | ~2 min (batch) | ~instant | ~2 min | ~instant |
| **Query Latency** | ~500ms | ~200ms | ~500ms | ~100ms |
| **Scalability (docs)** | ~1M+ | ~100M+ | ~10M+ | ~1M+ |
| **Cost/Month (10k queries)** | $50 (Bedrock KB) | $100–300 | $200–500 | Included (RDS) |
| **Integration with Agent** | Native | Via Lambda | Via Lambda | Via Lambda |
| **Multimodal Support** | Yes (images, PDFs) | Limited | Limited | Text only |
| **Metadata Filtering** | Yes | Yes | Yes | Yes |
| **Hybrid (Lexical + Vector)** | Limited | Yes | Yes | Limited |

**Rationale:**
- **Bedrock KB** chosen for **zero-ops vector indexing**, **native Bedrock Agent integration**, and **cost efficiency at MVP scale**.
- **Weaviate/Pinecone** rejected: higher cost; requires separate Lambda handlers (adds latency and ops burden).
- **OpenSearch**: good alternative but adds ES cluster overhead (provisioning, patching, cost).
- **pgvector only**: insufficient for non-spatial semantic search (e.g., "common wind patterns"); works well for numerical features but loses document retrieval.
- **Hybrid approach (Bedrock KB + PostGIS)**: KB for semantic doc retrieval; PostGIS for spatial queries → best of both.

**Indexing Strategy:**
- **Bedrock KB**: Ingest turbine metadata, wind patterns, domain knowledge docs (Markdown/PDF).
- **PostGIS**: Index spatial geometries (turbine locations, terrain boundaries, regions).
- **pgvector**: Store embeddings of extracted geospatial features (slope, NDVI).

**Cost Analysis (10k KB queries + 100k spatial queries/month):**
- Bedrock KB: ~$50 (KB indexing) + Bedrock API calls (~$15) = **$65/month**.
- Weaviate Cloud: ~$150/month base.
- OpenSearch: ~$300/month (m5.large.elasticsearch node + index cost).
- **Winner: Bedrock KB** (~4–5x cheaper than alternatives).

**Decision Record:** ✅ **APPROVED** — Use Bedrock KB for semantic search; PostGIS for spatial; pgvector for feature vectors.

---

### 4. Geospatial Processing & Feature Extraction

**Decision: AWS SageMaker Geospatial (async jobs) + PostGIS raster storage**

**Alternatives Considered:**
- Standalone GDAL/QGIS scripts (Lambda/ECS)
- ArcGIS Online / Google Earth Engine
- Rasterio/GeoPandas on SageMaker Processing
- In-database PostGIS raster functions

**Justification:**

| Factor | SageMaker Geospatial | GDAL Scripts | Earth Engine | GeoPandas | PostGIS Raster |
|--------|---------------------|-------------|------------|----------|----------------|
| **Ease of Use** | Very High (notebooks) | Medium | High (GUI) | Medium | Low |
| **Supported Analyses** | NDVI, slope, land cover, change detection | All (via GDAL) | Similar | Similar | Limited |
| **Integration** | Native AWS | DIY | Cloud-dependent | DIY | Native (RDS) |
| **Cost/Analysis** | $2–10 | $0.02–1 (compute) | Free tier, then $$$ | $0.02–1 | ~$0 (RDS-included) |
| **Latency** | ~5 min (job) | ~1–5 min | ~2 min | ~1–5 min | Seconds (queries) |
| **Scalability** | High (parallel jobs) | Medium | High | Medium | Medium (single DB) |
| **Pre-built Algorithms** | Yes (NDVI, slope, etc.) | No (DIY) | Yes | No (DIY) | No (DIY) |

**Rationale:**
- **SageMaker Geospatial** chosen for **pre-built geospatial algorithms**, **AWS-native integration**, and **notebook-friendly prototyping**.
- **GDAL scripts** rejected: requires GDAL binary packaging (complexity we solved with EFS earlier; now switching to Layers/containers). Reinventing wheel.
- **Earth Engine**: good for global satellite analysis but cloud-locked (Google); costs for high-volume queries.
- **GeoPandas**: valid for batch processing but requires container/instance management.
- **PostGIS Raster**: useful for querying pre-computed rasters; not ideal for computing (heavy lifting).
- **Hybrid Approach**: Use SageMaker Geospatial to **compute** features once/monthly; store as rasters in PostGIS for fast queries.

**Processing Pipeline:**
1. Monthly: Trigger SageMaker Geospatial job (async) → compute NDVI, slope, terrain from latest satellite data.
2. Output: GeoTIFF rasters → upload to PostGIS raster tables.
3. Queries: Agent calls Lambda → PostGIS ST_Value / ST_Intersects on raster → return feature values.

**Cost Analysis (10 analyses/month):**
- SageMaker Geospatial: ~$50/month (5 jobs × $10 each).
- GDAL/Lambda: ~$5 (compute) + ops.
- Earth Engine: ~$100+ (production usage).
- PostGIS Raster (storage): ~$10/month (RDS storage).
- **Winner: SageMaker Geospatial** (convenience + integration offset modest cost).

**Decision Record:** ✅ **APPROVED** — Use SageMaker Geospatial for feature computation; store results in PostGIS; query via PostGIS Raster API.

---

### 5. ML Model Serving (Wind Power Prediction)

**Decision: SageMaker Endpoint (serverless for variable load, or on-demand instances for steady state)**

**Alternatives Considered:**
- SageMaker Batch Transform (async)
- Lambda with model artifact
- ECS/Fargate container service
- EC2 with custom API

**Justification:**

| Factor | SageMaker Endpoint | Batch Transform | Lambda | ECS/Fargate | EC2 |
|--------|------------------|-----------------|--------|------------|-----|
| **Latency** | ~200ms | ~5 min | ~2 sec | ~1 sec | ~500ms |
| **Cost (100 predictions/day)** | ~$50–100/month (serverless) | ~$5/month (batch) | ~$1/month | ~$50/month | ~$150/month |
| **Scalability** | High (auto-scale) | Batch | Limited (cold start) | High | Manual |
| **Setup** | Easy (SageMaker UI) | Easy | Medium (packaging) | Medium | Hard |
| **Feature Freshness** | Real-time | Hourly/daily | Real-time | Real-time | Real-time |

**Rationale:**
- **SageMaker Serverless Endpoint** chosen for **low-latency inference** (200ms), **auto-scaling**, and **cost efficiency** (no provisioned instances when idle).
- **Batch Transform** rejected: acceptable for nightly model runs but too slow for real-time dashboard queries.
- **Lambda** rejected: model artifact size (if > 250 MB); cold start latency (~3–5 sec).
- **ECS/Fargate**: valid alternative if model is heavy or requires custom dependencies; adds ops overhead.
- **EC2**: only if running continuous inference workload; overkill for MVP.

**Deployment Strategy:**
1. Train model locally or on SageMaker Training.
2. Upload model artifact to S3.
3. Deploy to SageMaker Endpoint (serverless).
4. Lambda agent invokes endpoint via Boto3 (AWS SDK).

**Cost Analysis (100 predictions/day):**
- Serverless: ~$0.0035 per prediction → **$100/month** (includes invocations + GB-hours).
- Batch Transform (nightly): ~$5/month.
- Lambda: ~$1/month (compute) + cold start risk.
- **Winner: Serverless Endpoint** (real-time, responsive).

**Trade-off Note:** For nightly batch predictions (e.g., 7-day forecasts for all turbines), use **Batch Transform** (cheaper); real-time dashboard uses **Endpoint** (fast).

**Decision Record:** ✅ **APPROVED** — Use SageMaker Serverless Endpoint for real-time predictions; Batch Transform for scheduled batch runs.

---

### 6. Frontend & Visualization

**Decision: React (SPA) + MapLibre GL (open-source mapping) + S3 + CloudFront**

**Alternatives Considered:**
- Mapbox GL (commercial mapping)
- Leaflet + Tile Server
- ArcGIS JavaScript API
- Dash (Python-based)
- Tableau / Looker

**Justification:**

| Factor | React + MapLibre | Mapbox | Leaflet | ArcGIS | Dash | Tableau |
|--------|-----------------|--------|---------|--------|------|---------|
| **Cost/Month** | $5–10 (S3+CF) | $100+ (Mapbox API) | $5–10 (OSS) | $200+ | $50 | $500+ |
| **Customization** | Very High | High | High | Medium | High | Low |
| **Learning Curve** | Medium | Medium | Low | High | Low | Low |
| **Real-time Updates** | Yes (WebSocket) | Yes | Yes | Yes | Limited | No |
| **Mobile Support** | Excellent | Excellent | Good | Good | Fair | Good |
| **Performance** | Excellent | Excellent | Good | Fair | Fair | Fair |
| **3D Capability** | Yes (Deck.gl) | Yes | No | Yes | No | No |

**Rationale:**
- **React + MapLibre** chosen for **cost efficiency** (open-source tiles + free CDN via S3+CloudFront), **customization**, and **modern web stack compatibility**.
- **Mapbox** rejected: high per-request cost (~$5 per 1000 requests) for wind data queries (potentially 100k/month = $500/month).
- **Leaflet**: good alternative but less powerful for 3D/complex visualizations; fewer out-of-box features.
- **ArcGIS**: cost-prohibitive for MVP; steep learning curve.
- **Dash/Tableau**: less control over UX; vendor lock-in.

**Frontend Architecture:**
```
React App (AWS S3)
  → ChatWidget (calls Agent API)
  → MapLibre (displays turbine locations, predictions, geospatial layers)
  → TimeSeries Chart (power output, wind speed, model confidence)
  → AlertPanel (maintenance, anomalies)
Hosted on: S3 + CloudFront (CDN)
Auth: Cognito JWT → API Gateway
```

**Cost Analysis (1000 users/month):**
- S3 + CloudFront: ~$10/month (small data transfer).
- Mapbox: ~$500/month (if 100k tile requests).
- Self-hosted tile server: ~$50/month (compute) + maintenance.
- **Winner: React + MapLibre** (10–50x cheaper).

**Decision Record:** ✅ **APPROVED** — Use React + MapLibre; host on S3 + CloudFront; use Mapbox Streets (free tier) or self-hosted tiles.

---

### 7. Authentication & Access Control

**Decision: Amazon Cognito (user pools) + API Gateway authorizer**

**Alternatives Considered:**
- Auth0
- Keycloak (self-hosted)
- IAM (for AWS-only users)
- OIDC provider (generic)

**Justification:**

| Factor | Cognito | Auth0 | Keycloak | IAM | OIDC |
|--------|---------|-------|----------|-----|------|
| **Cost** | Free (up to 50k) | $25–100/month | Minimal (OSS) | Minimal | Depends |
| **Setup** | Easy (AWS) | Easy | Medium | Hard | Medium |
| **MFA** | Yes | Yes | Yes | Yes | Optional |
| **Federated Login** | Yes (Google, Facebook, AD) | Yes | Yes | Limited | Yes |
| **User Management** | Built-in | Built-in | Built-in | No | No |
| **API Integration** | Native (API Gateway) | Via middleware | Via middleware | Direct | Via middleware |

**Rationale:**
- **Cognito** chosen for **zero-cost at MVP scale** (<50k users free), **AWS-native integration** (seamless with API Gateway), and **simple setup**.
- **Auth0**: good alternative but monthly cost ($25–100) for small user base.
- **Keycloak**: operational complexity (self-hosted) not justified for MVP.
- **IAM**: too restrictive (AWS staff only); not suitable for external users.
- **OIDC**: generic but requires additional middleware.

**Auth Flow:**
1. User logs in → Cognito pool.
2. Cognito returns JWT token.
3. Frontend sends JWT to API Gateway.
4. API Gateway invokes Cognito authorizer.
5. Authorizer validates JWT → grants access to Lambda.

**Cost Analysis (1000 users):**
- Cognito: **Free** (50k user limit).
- Auth0: **$25–100/month**.
- Keycloak: **$0** (OSS) + ~$100/month ops (if self-hosted).
- **Winner: Cognito** (no cost at MVP scale).

**Decision Record:** ✅ **APPROVED** — Use Cognito for auth; add RBAC in Lambda (read-only vs. admin vs. data-scientist tiers).

---

## Summary Table: All Decisions

| Component | Choice | Cost/Month | Latency | Operational Effort |
|-----------|--------|-----------|---------|-------------------|
| **LLM** | Claude 3 (Bedrock) | $50–100 | 2–4 sec | Minimal |
| **Orchestration** | Bedrock Agents | $5 | 10–30 sec | Minimal |
| **Knowledge Base** | Bedrock KB | $50–100 | 500 ms | Minimal |
| **Geospatial** | SageMaker Geospatial | $50–100 | 5 min (job) | Low |
| **ML Inference** | SageMaker Endpoint (serverless) | $50–100 | 200 ms | Low |
| **Frontend** | React + MapLibre | $10 | <1 sec | Medium |
| **Auth** | Cognito | Free | <100 ms | Minimal |
| **Database** | RDS + PostGIS + pgvector | $200–400 | <100 ms | Low |
| **Storage** | S3 + Intelligent-Tiering | $20–50 | <100 ms | Minimal |
| **TOTAL** | — | **$435–950/month** | **~15–40 sec (end-to-end)** | **Low–Medium** |

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| **Bedrock API limits** | Request quota increase; implement rate limiting in Lambda. |
| **KB retrieval relevance** | Iterate document chunking; use Bedrock API logs to tune. |
| **Agent hallucinations** | Use Bedrock Guardrails; add confidence thresholds; human-in-loop for critical queries. |
| **Model prediction errors** | A/B test models; track RMSE on hold-out set; retrain monthly. |
| **Geospatial job failures** | Implement retry logic; alert on failure; fallback to cached results. |
| **High latency (>30 sec)** | Cache frequent queries; reduce agent reasoning steps; parallel action invocation. |

---

## Next Steps

1. **Week 1**: Set up Bedrock account + Knowledge Base ingestion; create test queries.
2. **Week 2**: Define Bedrock Agent + action groups; implement Lambda handlers.
3. **Week 3**: Deploy SageMaker Endpoint + Geospatial notebooks; integrate with Agent.
4. **Week 4**: Build frontend (React + MapLibre); deploy to S3 + CloudFront.
5. **Week 5**: End-to-end testing; performance tuning; documentation.

---

**Document Version:** 1.0  
**Last Updated:** 2026-08-27  
**Author:** GenAI Platform Team  
**Status:** APPROVED (Ready for implementation)
