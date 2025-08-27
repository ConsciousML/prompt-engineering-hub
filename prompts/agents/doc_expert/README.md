![Status](https://img.shields.io/badge/status-beta-orange)
[![GitHub Release](https://img.shields.io/github/release/ConsciousML/prompt-engineering-hub.svg?style=flat)]()

# Code Documentation Expert

## Overview
The Code Documentation Expert is an AI assistant that helps you create comprehensive documentation through an iterative, collaborative process. It specializes in two key areas:
- **README documentation**: Complete README files for projects
- **Code docstrings**: Inline documentation for functions, classes, and modules

## When to Use
Use the Code Documentation Expert when you want to:
- Create a new README from scratch for any type of project
- Generate appropriate docstrings for your code
- Ensure your documentation follows best practices
- Build documentation iteratively with guidance at each step
- Generate clean, professional documentation that's easy to maintain
- Balance completeness with maintainability in your documentation

## Features
### README Documentation
- **Three-phase collaborative process**:
1. Information gathering
2. Outline creation  
3. Section-by-section writing
- **Adaptive documentation**: Automatically adjusts sections and content based on your project type
- **Best practices built-in**: Generates READMEs following established documentation standards
- **Iterative refinement**: Review and modify each section before moving to the next
- **Smart organization**: Suggests separate documentation files when sections would make the README too lengthy
- **Complete Markdown formatting**: Produces properly formatted headers, lists, code blocks, and links

### Code Docstrings
- **Intelligent documentation**: Generates appropriate docstrings that balance completeness with maintainability
- **Context-aware**: Analyzes your code to create relevant documentation without over-documenting obvious implementation details
- **Best practices**: Follows language-specific docstring conventions and standards

## How to Use
Follow our [setup guide](../../../docs/setup-guide.md) to add the Code Documentation Expert to your workspace.

Once set up, the assistant will ask you to choose between two documentation types:

### For README Documentation
Simply provide initial information about your project (name, file structure, purpose).
The assistant will guide you through creating each section using a three-phase process.

### For Code Docstrings
Provide the code you want documented, and the assistant will generate appropriate docstrings following best practices and your project's conventions.

Here's a [detailed example](examples/claude_prompt_catalog.xml) on how to best use this assistant.

## Tips
- **Have your project structure ready**: Use `tree` command output or list your main files/folders for better results
- **Iterate on sections**: Don't hesitate to ask for revisions on any section before moving forward