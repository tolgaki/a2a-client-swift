# Contributing to A2AClient

Thank you for your interest in contributing to A2AClient! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Code Style](#code-style)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Issue Guidelines](#issue-guidelines)

## Code of Conduct

This project follows a standard code of conduct. Please be respectful and constructive in all interactions. We are committed to providing a welcoming and inclusive environment for everyone.

## Getting Started

### Prerequisites

- Xcode 16.0 or later
- Swift 6.0 or later
- macOS 14.0 or later (for development)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/YOUR-USERNAME/a2a-client-swift.git
cd a2a-client-swift
```

3. Add the upstream remote:

```bash
git remote add upstream https://github.com/tolgaki/a2a-client-swift.git
```

## Development Setup

### Opening the Project

Open the package in Xcode:

```bash
open Package.swift
```

Or use the Swift CLI:

```bash
swift build
swift test
```

### Project Structure

```
a2a-client-swift/
├── Package.swift              # Package manifest
├── Sources/
│   └── A2AClient/
│       ├── A2AClientModule.swift
│       ├── Client/            # Main client implementation
│       ├── Models/            # Data models
│       ├── Transport/         # Transport layer
│       ├── Authentication/    # Auth providers
│       ├── Streaming/         # Streaming support
│       └── Extensions/        # Utility extensions
└── Tests/
    └── A2AClientTests/        # Unit tests
```

## Making Changes

### Branch Strategy

- Create feature branches from `main`
- Use descriptive branch names:
  - `feature/add-retry-policy`
  - `fix/streaming-timeout`
  - `docs/update-readme`

```bash
git checkout -b feature/your-feature-name
```

### Commit Messages

Follow conventional commit format:

```
type(scope): brief description

Longer description if needed.

Fixes #123
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:

```
feat(client): add retry policy configuration

Add configurable retry policy with exponential backoff
for transient network failures.

Fixes #42
```

```
fix(streaming): handle connection timeout properly

The SSE connection was not properly cleaned up when
a timeout occurred, leading to resource leaks.
```

## Code Style

### Swift Style Guidelines

We follow standard Swift conventions:

1. **Naming**
   - Use camelCase for variables and functions
   - Use PascalCase for types
   - Use descriptive names that indicate purpose

2. **Access Control**
   - Mark types and members with appropriate access levels
   - Default to `private` and relax as needed
   - Use `public` for API surface

3. **Documentation**
   - Document all public APIs with doc comments
   - Use `///` for single-line doc comments
   - Include parameter and return value documentation

```swift
/// Sends a message to the agent and returns the response.
///
/// - Parameters:
///   - message: The message to send
/// - Returns: The agent's response, either a message or a task
/// - Throws: `A2AError` if the request fails
public func sendMessage(_ message: Message) async throws -> SendMessageResponse
```

4. **Code Organization**
   - Group related functionality using `// MARK:` comments
   - Order members: properties, initializers, public methods, private methods
   - Keep files focused on a single responsibility

5. **Modern Swift**
   - Use `async/await` for asynchronous code
   - Prefer value types (structs/enums) over reference types
   - Use `guard` for early exits
   - Leverage Swift's type system

### Formatting

- Use 4-space indentation
- Maximum line length of 120 characters
- No trailing whitespace

Consider using SwiftFormat or SwiftLint for consistency.

## Testing

### Running Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter A2AClientTests.ModelTests

# Run with verbose output
swift test --verbose
```

### Writing Tests

1. **Test File Naming**: `*Tests.swift` (e.g., `MessageTests.swift`), using XCTest

2. **Test Structure**:

```swift
import XCTest
@testable import A2AClient

final class MessageTests: XCTestCase {
    func testUserMessageRole() {
        let message = Message.user("Hello")
        XCTAssertEqual(message.role, .user)
    }

    func testMessageEncoding() throws {
        let message = Message.user("Test")
        let data = try JSONEncoder().encode(message)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["role"] as? String, "user")
    }
}
```

3. **Test Categories**:
   - Unit tests for individual components
   - Integration tests for component interactions
   - Encode/decode tests for all models

4. **Test Coverage**:
   - All public APIs should have tests
   - Cover happy paths and error cases
   - Test edge cases and boundary conditions

### Test Best Practices

- Tests should be independent and repeatable
- Use descriptive test names that explain what is being tested
- Keep tests focused on one behavior
- Avoid testing implementation details

## Submitting Changes

### Before Submitting

1. **Ensure all tests pass**:
   ```bash
   swift test
   ```

2. **Build successfully**:
   ```bash
   swift build
   ```

3. **Update documentation** if you changed APIs

4. **Add tests** for new functionality

### Pull Request Process

1. Push your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Open a Pull Request against the `main` branch

3. Fill out the PR template with:
   - Description of changes
   - Related issue numbers
   - Testing performed
   - Screenshots if applicable

4. Wait for CI checks to pass

5. Address review feedback

### PR Guidelines

- Keep PRs focused on a single change
- Break large changes into smaller PRs
- Respond to review comments promptly
- Rebase on main if needed to resolve conflicts

## Issue Guidelines

### Reporting Bugs

When reporting bugs, include:

1. **Environment**:
   - macOS/iOS version
   - Xcode version
   - Swift version
   - A2AClient version

2. **Steps to Reproduce**:
   - Minimal code example
   - Expected behavior
   - Actual behavior

3. **Additional Context**:
   - Error messages
   - Stack traces
   - Related issues

### Feature Requests

For feature requests:

1. **Describe the problem** you're trying to solve
2. **Propose a solution** with API examples if possible
3. **Consider alternatives** you've explored
4. **Note any breaking changes** the feature might require

### Issue Labels

- `bug`: Something isn't working
- `enhancement`: New feature request
- `documentation`: Documentation improvements
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention needed
- `question`: Further information requested

## Development Tips

### Debugging

Use Xcode's debugger or add logging:

```swift
#if DEBUG
print("Debug: \(message)")
#endif
```

### Working with Async Code

Test async code with XCTest:

```swift
func testAsyncOperation() async throws {
    let result = try await client.sendMessage("Test")
    XCTAssertTrue(result.isMessage)
}
```

### Mock Objects

Use protocols for testability:

```swift
// In tests
struct MockTransport: A2ATransport {
    var mockResponse: Any?

    func send<Request, Response>(
        request: Request,
        to endpoint: A2AEndpoint,
        responseType: Response.Type
    ) async throws -> Response {
        return mockResponse as! Response
    }
}
```

## Getting Help

- Open an issue for questions
- Check existing issues and discussions
- Review the [DESIGN.md](DESIGN.md) for architecture context

## Recognition

Contributors will be acknowledged in release notes. Significant contributions may be recognized in the README.

Thank you for contributing to A2AClient!
