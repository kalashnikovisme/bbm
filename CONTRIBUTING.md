# Contributing to BBM

Thank you for your interest in contributing to BBM! This document provides guidelines and instructions for contributing.

## Development Setup

1. Clone the repository
2. Install Ruby 2.7+ (3.2.0 recommended)
3. Run `make install` or `bundle install`
4. Copy `.env.example` to `.env` and add your credentials
5. Run tests: `make test` or `bundle exec rspec`

## Making Changes

1. Create a new branch from `main`
2. Make your changes
3. Add tests for new functionality
4. Ensure all tests pass: `make test`
5. Ensure code passes linting: `make lint`
6. Commit your changes with a clear message
7. Push to your fork and submit a pull request

## Code Style

- Follow Ruby style guide
- Use RuboCop for linting: `bundle exec rubocop`
- Auto-fix issues when possible: `bundle exec rubocop -A`
- Keep methods small and focused
- Add tests for new features

## Testing

- Write RSpec tests for new functionality
- Use WebMock to stub external API calls
- Ensure test coverage for edge cases
- Run tests before submitting PR: `bundle exec rspec`

## Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, etc.)
- Reference issue numbers when applicable

## Pull Requests

- Provide a clear description of changes
- Link to related issues
- Ensure CI checks pass
- Be responsive to feedback

## Questions?

Open an issue for questions or discussions about the project.
