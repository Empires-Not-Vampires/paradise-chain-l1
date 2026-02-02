# Security Policy

## Supported Versions

We currently support the following versions with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via one of the following methods:

1. **Email**: security@paradise.cloud
2. **Discord**: Contact the Paradise Tycoon team directly

Please include the following information in your report:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Security Disclosure Process

1. Report the vulnerability privately
2. We will acknowledge receipt within 48 hours
3. We will investigate and provide an initial assessment within 7 days
4. We will work with you to develop a fix
5. Once fixed, we will coordinate public disclosure

## Security Best Practices

### For Developers

- Never commit private keys or mnemonics
- Use environment variables for sensitive data
- Review all code changes before merging
- Run security analysis tools (Slither, Mythril)
- Test thoroughly before deployment

### For Users

- Never share your private keys
- Verify contract addresses before interacting
- Use hardware wallets for large amounts
- Review transaction details before signing
- Be cautious of phishing attempts

## Known Security Considerations

### Unaudited Contracts

**These contracts have NOT been professionally audited.** They are provided as-is for transparency and community review. Use at your own risk.

### Upgradeability

Current contracts are not upgradeable. Future versions may use proxy patterns for upgradeability, which will be clearly documented.

### Centralization Risks

- Admin roles have significant control
- Emergency pause functions exist
- Treasury withdrawals require admin approval

These are intentional design decisions for game management but should be understood by users.

## Bug Bounty

We do not currently operate a formal bug bounty program, but responsible disclosures are appreciated and may be rewarded at our discretion.

## Security Audit Status

- **Status**: Not audited
- **Planned**: TBD
- **Auditor**: TBD

## Additional Resources

- [OpenZeppelin Security Center](https://security.openzeppelin.com/)
- [Consensys Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Paradise Chain Documentation](https://docs.paradise.cloud)
