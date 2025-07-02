FROM alpine:3.18

# Install system packages
RUN apk add --no-cache curl jq python3 py3-pip wget unzip && \
    wget https://releases.hashicorp.com/vault/1.20.0/vault_1.20.0_linux_amd64.zip && \
    unzip vault_1.20.0_linux_amd64.zip && mv vault /usr/local/bin/ && rm vault_1.20.0_linux_amd64.zip

# RUN addgroup -g 9999 sharedgroup && \
#     adduser -D -G sharedgroup -u 9999 vaultuser

# USER vaultuser

# Install Python dependencies
RUN pip install --no-cache-dir hvac

WORKDIR /app

COPY . /app

CMD ["python3", "app.py"]
