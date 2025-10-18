# .cursor Directory

This directory contains long-term memory and reference documentation for the Stocks AU Web project. These files are designed to help AI coding assistants (like Claude in Cursor) understand the project structure, conventions, and best practices.

## Files in this Directory

### `project-memory.md`
**Purpose**: Comprehensive project documentation  
**Use**: When you need to understand the overall architecture, tech stack, file structure, or how different parts of the system work together.

**Contains**:
- Project overview and purpose
- Complete tech stack details
- Directory structure
- Backend API endpoints and patterns
- Frontend pages and routing
- Database schema information
- Environment configuration
- Development workflow
- Common issues and solutions

### `quick-reference.md`
**Purpose**: Fast lookup guide for common tasks  
**Use**: When you need to quickly find a command, URL, or code snippet.

**Contains**:
- Essential commands (start/stop apps, logs)
- URLs and endpoints
- Database stored procedures
- API endpoint examples
- Common tasks and how-to guides
- Troubleshooting steps
- Key patterns and code snippets

### `coding-conventions.md`
**Purpose**: Style guide and best practices  
**Use**: When writing new code or refactoring existing code to maintain consistency.

**Contains**:
- General coding principles
- Backend (Python/FastAPI) patterns
- Frontend (Next.js/React) patterns
- CSS/Tailwind styling conventions
- Testing and debugging approaches
- Security best practices
- Naming conventions
- Common mistakes to avoid

## How to Use These Files

### For AI Assistants
These files provide context about the project that helps generate more accurate and consistent code. Reference them when:
- Starting a new task in the project
- Adding new features
- Debugging issues
- Answering user questions about the project
- Maintaining coding standards

### For Developers
These files serve as living documentation. When working in Cursor:
- Ask Claude to reference these files for project context
- Update them when architectural decisions change
- Add new patterns as they emerge
- Keep conventions current with the evolving codebase

## Keeping These Files Updated

These memory files should be updated when:
- New features are added (update project-memory.md)
- API endpoints change (update quick-reference.md and project-memory.md)
- Coding patterns evolve (update coding-conventions.md)
- New best practices are established (update coding-conventions.md)
- Database schema changes (update project-memory.md and quick-reference.md)
- Environment configuration changes (update project-memory.md)

## File Maintenance

**Created**: October 17, 2025  
**Last Updated**: October 17, 2025  
**Version**: 1.0

To update these files, simply ask Claude (or edit manually):
```
"Please update the .cursor/project-memory.md to reflect the new API endpoint structure"
"Add the new database pattern to coding-conventions.md"
```

## Additional Resources

For more context, also refer to:
- `/CLAUDE.md` - Project structure and development commands (in repo root)
- `/backend/README.md` - Backend-specific setup and run instructions
- `/frontend/README.md` - Frontend-specific setup (Next.js boilerplate)
- Backend API docs: http://localhost:3101/docs (when running)

## Notes

- These files are stored in `.cursor/` which should be in `.gitignore` if they contain any sensitive information
- Feel free to add more specialized memory files as needed (e.g., `.cursor/database-schema.md`, `.cursor/api-reference.md`)
- Keep formatting consistent with markdown best practices for easy reading

