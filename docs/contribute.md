---
icon: material/account-group
---

# Contributing

This is a personal learning project, but feedback and contributions are welcome!

## Ways to Contribute

### 🐛 Report Issues

Found a bug or have a suggestion? [Open an issue on GitHub](https://github.com/cwagne17/homelab/issues).

### 💡 Share Ideas

Have ideas for improvements? Start a [GitHub Discussion](https://github.com/cwagne17/homelab/discussions).

### 🔧 Submit Pull Requests

Want to contribute code? PRs are welcome for:

- Bug fixes
- Documentation improvements
- New features
- Configuration examples
- Test coverage

## Development

### Setting Up Development Environment

1. **Fork the repository**

   ```bash
   git clone https://github.com/YOUR_USERNAME/homelab.git
   cd homelab
   ```

2. **Create a branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**

   - Follow existing code style
   - Update documentation
   - Add tests if applicable

4. **Test your changes**

   ```bash
   # Validate Atmos configuration
   atmos validate stacks

   # Validate Packer templates
   atmos packer validate alma9-k3s-optimized -s pve-prod

   # Validate OpenTofu configuration
   atmos terraform validate k3s-cluster -s pve-prod
   ```

5. **Commit and push**

   ```bash
   git add .
   git commit -m "feat: add your feature description"
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request**

### Code Style Guidelines

- **Terraform/OpenTofu**: Use `tofu fmt` for formatting
- **Packer**: Use `packer fmt` for formatting
- **YAML**: Use 2-space indentation
- **Markdown**: Follow existing documentation style
- **Commit Messages**: Use conventional commits format

### Documentation

When adding features:

- Update relevant documentation pages
- Add examples where appropriate
- Include troubleshooting tips
- Update the README if needed

### Testing

Before submitting:

- Run validation scripts
- Test in a non-production environment
- Verify documentation renders correctly
- Check for broken links

## Project Structure

```
homelab/
├── components/          # Atmos components
│   ├── terraform/      # OpenTofu modules
│   └── packer/         # Packer templates
├── stacks/             # Atmos stacks
│   ├── catalog/        # Reusable configs
│   ├── deploy/         # Deployment stacks
│   └── workflows/      # Automation workflows
├── k8s/                # Kubernetes manifests
├── docs/               # Documentation
└── .kiro/specs/        # Feature specifications
```

## Questions?

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and ideas
- **LinkedIn**: Connect at [cwagnerdevops](https://www.linkedin.com/in/cwagnerdevops)

## License

This project is open source and available under the MIT License.

---

**Thank you for contributing!** 🎉
