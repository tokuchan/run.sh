FROM nixos/nix:latest

# Enable flakes and disable sandbox (required inside containers)
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf \
    && echo "sandbox = false" >> /etc/nix/nix.conf

WORKDIR /workspace
CMD ["/bin/bash"]
