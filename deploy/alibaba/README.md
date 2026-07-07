# Alibaba Cloud Deploy

This directory contains the Devpost proof file for Alibaba Cloud deployment:

- `serverless-devs.yaml`: Function Compute custom container definition

The backend exposes `/api/health`, which returns Qwen model metadata and the
proof file path without exposing secrets.
