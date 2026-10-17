FROM python:3.10-slim

# Install system dependencies (curl, git, nodejs, build-essential)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    locales \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV PYTHONUNBUFFERED=1
ENV PORT=8000

WORKDIR /app

# Install jaclang 0.34.24
RUN pip install --no-cache-dir jaclang==0.34.24 pytest requests anyio

# Copy project files
COPY . /app

# Clean and install project dependencies
RUN jac install || true

EXPOSE 8000

# Start server
CMD ["sh", "-c", "jac start --port ${PORT}"]
