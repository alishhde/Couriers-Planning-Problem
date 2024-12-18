# Use MiniZinc base image
FROM minizinc/minizinc:2.8.7-jammy

# Set environment variables for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and Python
RUN apt-get update && apt-get install -y \
    python3.9 \
    python3-pip \
    wget \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements file first for better caching
COPY requirements.txt /app/

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy all project files
COPY . /app/

# Create necessary directories
RUN mkdir -p /app/res/MiniZinc

# Make sure all scripts are executable
RUN chmod +x /app/Main_MZN.py

# Set environment variables
ENV PYTHONPATH=/app

# Verify installations
RUN echo "=== Python Version ===" && \
    python3 --version && \
    echo "\n=== MiniZinc Version ===" && \
    minizinc --version && \
    echo "\n=== Available Solvers ===" && \
    minizinc --solvers

# Default command
ENTRYPOINT ["python3", "/app/Docker_Main_MZN.py"]