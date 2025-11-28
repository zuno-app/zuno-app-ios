# Zuno iOS App Documentation

This directory contains documentation for the Zuno iOS application.

## 📚 Documentation Index

### Troubleshooting Guides

- **[SwiftData & ViewModel Issues](TROUBLESHOOTING-SWIFTDATA-VIEWMODELS.md)**
  - Comprehensive guide for debugging view state and persistence issues
  - Root cause analysis and solutions
  - Prevention strategies and best practices
  - **Use when:** Buttons not responding, state not persisting, silent failures

- **[Quick Reference: ViewModel Patterns](QUICK-REFERENCE-VIEWMODEL-PATTERNS.md)**
  - Fast lookup for correct ViewModel patterns
  - Common mistakes and their fixes
  - Code templates for emergency fixes
  - **Use when:** You need a quick reminder of the correct pattern

## 🔍 Quick Problem Finder

### Issue: Buttons/Actions Not Working
→ See: [TROUBLESHOOTING-SWIFTDATA-VIEWMODELS.md](TROUBLESHOOTING-SWIFTDATA-VIEWMODELS.md)

### Issue: State Not Persisting Across Views
→ See: [TROUBLESHOOTING-SWIFTDATA-VIEWMODELS.md](TROUBLESHOOTING-SWIFTDATA-VIEWMODELS.md)

### Need Quick Code Example?
→ See: [QUICK-REFERENCE-VIEWMODEL-PATTERNS.md](QUICK-REFERENCE-VIEWMODEL-PATTERNS.md)

## 🛠️ Development Resources

### Architecture Guidelines
See [/zuno-project/.kiro/steering/](../../../.kiro/steering/) for comprehensive architecture docs:
- `ios-specific.md` - iOS development best practices
- `architecture.md` - Overall system architecture
- `tech.md` - Technology stack decisions

### Project Overview
See [/zuno-project/CLAUDE.md](../../../CLAUDE.md) for:
- Project structure
- Development workflow
- Git submodule commands
- Testing procedures

## 📝 Contributing to Documentation

When adding new documentation:

1. **Troubleshooting Guides**
   - Document the problem, cause, and solution
   - Include code examples (before/after)
   - Add prevention strategies
   - Update this README index

2. **Quick References**
   - Keep it concise (one page max)
   - Use tables and code blocks
   - Include search commands
   - Link to detailed docs

3. **Naming Convention**
   - Troubleshooting: `TROUBLESHOOTING-{TOPIC}.md`
   - Quick Reference: `QUICK-REFERENCE-{TOPIC}.md`
   - Guides: `GUIDE-{TOPIC}.md`

## 🔗 External Resources

- [Apple SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Swift.org Documentation](https://www.swift.org/documentation/)

---

**Last Updated:** November 18, 2025
