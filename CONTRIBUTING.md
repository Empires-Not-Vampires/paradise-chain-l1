# Contributing to Paradise Chain L1

Thank you for your interest in contributing! This document provides guidelines for contributing to the Paradise Chain L1 smart contracts.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/paradise-chain-l1.git`
3. Install dependencies: `npm install`
4. Create a branch: `git checkout -b feature/your-feature-name`

## Development Workflow

### Before Making Changes

1. Check existing issues and pull requests
2. Create an issue to discuss major changes
3. Ensure you understand the architecture (see README.md)

### Making Changes

1. Write clear, well-documented code
2. Follow Solidity style guide (see `.solhint.json`)
3. Add NatSpec comments for all public functions
4. Write tests for new functionality
5. Update documentation as needed

### Code Style

- Use 4 spaces for indentation
- Maximum line length: 120 characters
- Use descriptive variable names
- Add comments for complex logic
- Follow OpenZeppelin patterns where applicable

### Testing

- Write tests for all new functions
- Ensure existing tests pass: `npm test`
- Aim for high test coverage
- Test edge cases and error conditions

### Commit Messages

Use clear, descriptive commit messages:

```
feat: Add new powerup buff type
fix: Correct auction house fee calculation
docs: Update README with deployment instructions
test: Add tests for quest reward claiming
```

## Pull Request Process

1. **Update your branch**: Rebase on latest `main` branch
2. **Run checks**: Ensure linting and tests pass
   ```bash
   npm run lint
   npm test
   ```
3. **Create PR**: Provide clear description of changes
4. **Address feedback**: Respond to review comments
5. **Wait for approval**: At least one maintainer approval required

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] No hardcoded addresses or keys
- [ ] Gas optimizations considered
- [ ] Security implications reviewed

## Contract Development Guidelines

### Security

- **Fail fast**: No fallback values, throw on invalid input
- **No defensive code**: Don't guard against impossible states
- **Explicit over implicit**: Clear error messages
- **Reentrancy**: Use `ReentrancyGuard` where needed
- **Access control**: Use role-based access control

### Gas Optimization

- Use `uint256` for all integers (no smaller types)
- Pack structs efficiently
- Avoid loops where possible
- Use events for off-chain data
- Consider batch operations

### Testing Requirements

- Unit tests for each function
- Integration tests for workflows
- Edge case testing
- Gas usage benchmarks

## Documentation

### NatSpec Comments

All public/external functions must have NatSpec:

```solidity
/**
 * @notice Brief description
 * @param paramName Parameter description
 * @return Return value description
 * @dev Implementation details
 */
```

### README Updates

Update README.md if:
- Adding new contracts
- Changing deployment process
- Adding new features
- Updating network information

## Questions?

- Open an issue for questions
- Check existing issues first
- Review code comments and documentation

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
