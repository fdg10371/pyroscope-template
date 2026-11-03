# -------- Base stage --------
# Installs dependencies. Shared by build and (optionally) development stages.
FROM node:18-alpine AS base

# Define the build arguments here
ARG environment=dev

# Create application image below