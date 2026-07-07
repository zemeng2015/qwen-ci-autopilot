export interface Scenario {
  id: string
  title: string
  owner: string
  signal: string
  risk: 'low' | 'medium' | 'high'
  description: string
  input: string
}

export const scenarios: Scenario[] = [
  {
    id: 'java-ci-coverage-gate',
    title: 'Spring Boot CI coverage gate',
    owner: 'Payments platform',
    signal: 'Maven test failure + JaCoCo gate',
    risk: 'medium',
    description:
      'A release branch is blocked by a regression in a mapper test and a coverage gate drop.',
    input: `GitHub Actions job: release-ci / payments-service
Branch: release/2026.07.09

Command:
mvn -q -pl payments-service -am test jacoco:report

Failure:
java.lang.NullPointerException: Cannot invoke "PricingRule.getType()" because "rule" is null
  at com.acme.payments.pricing.PricingRulesMapper.toDto(PricingRulesMapper.java:87)
  at com.acme.payments.pricing.PricingRulesMapperTest.mapsTieredRule(PricingRulesMapperTest.java:42)

Coverage gate:
Instruction coverage for com.acme.payments.pricing dropped from 82.4% to 77.1%.
Required minimum is 80.0%.

Changed files:
payments-service/src/main/java/com/acme/payments/pricing/PricingRulesMapper.java
payments-service/src/test/java/com/acme/payments/pricing/PricingRulesMapperTest.java

Human constraint:
Do not modify production pricing formulas without reviewer approval. Test-only fixes are okay.`,
  },
  {
    id: 'crawler-rate-limit',
    title: 'Product discovery crawler rate limit',
    owner: 'Commerce intelligence',
    signal: 'Public-web retrieval degraded',
    risk: 'high',
    description:
      'A product-discovery pipeline is returning sparse competitor evidence after rate-limit errors.',
    input: `Incident: competitor research job returns 206 partial evidence sets.
Pipeline: firecrawl-retriever -> scorer -> product-gap-report
Observed errors:
HTTP 429 from 3 domains, 14 duplicate URLs, 8 stale cache hits older than 72h.

Changed files:
src/retrieval/firecrawlClient.ts
src/scoring/evidenceRanker.ts
server/jobs/productDiscoveryJob.ts

Business impact:
Sales team cannot trust generated product-gap reports for Monday outreach.

Human constraint:
Do not bypass robots.txt or scrape authenticated pages. Prefer graceful degradation and audit logs.`,
  },
  {
    id: 'production-alert',
    title: 'Workflow upload production alert',
    owner: 'Enterprise workflow UI',
    signal: 'CloudWatch alarm + S3 preview failures',
    risk: 'high',
    description:
      'A customer-facing upload workflow is failing intermittently after a front-end release.',
    input: `CloudWatch alarm: UploadPreview5xxHigh
Region: us-east-1
Service: workflow-api
Symptom: users upload workflow JSON, preview fails, download still succeeds.

Logs:
GET /api/workflows/preview/s3://hera-workflow-bucket/tmp/2026-07/run-188.json 502
Error: Missing signed URL expiry value
at PreviewUrlService.createSignedUrl(PreviewUrlService.java:63)

Likely related UI files:
src/app/workflow/workflow-upload.component.ts
src/app/workflow/workflow-preview.service.ts

Human constraint:
Any change to S3 signing expiry or customer-visible retention needs product-owner approval.`,
  },
]

export function getScenario(id: string): Scenario {
  return scenarios.find((scenario) => scenario.id === id) ?? scenarios[0]
}
