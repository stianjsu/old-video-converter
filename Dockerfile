FROM alpine:latest

# Install ffmpeg
RUN apk add --no-cache ffmpeg bash

# Create working directories
WORKDIR /app
RUN mkdir -p input output

# Copy the conversion script
COPY convert.sh /app/convert.sh
RUN chmod +x /app/convert.sh

# Run the script
CMD ["/app/convert.sh"]