# Cursor Resources

This repository serves as a centralized collection of resources to maximize productivity with Cursor, the AI-powered IDE. It contains prompts, rules, Model Context Protocol (MCP) servers, scripts, and other utilities that enhance the Cursor development experience.

## Contents

- **Global Rules**: Custom behavior rules for Cursor's AI to follow specific patterns and workflows
- **Project Rules**: Directory-specific rules for granular control over AI behavior
- **Model Context Protocol Servers**: Custom MCP implementations for enhanced context handling
- **Scripts**: Utility scripts for automation and workflow enhancement
- **Architecture Planning**: Documentation and diagrams for various components
- **Language & Framework Specific Resources**: Specialized rules and prompts for different tech stacks

## Why These Resources Matter

Cursor's power comes from its ability to be customized and enhanced through various mechanisms:

1. **Rules for AI** (@Web https://docs.cursor.com/context/rules-for-ai):
   
   a. **Global Rules**:
   - Apply to all projects and conversations in Cursor
   - Set through Cursor Settings > General > Rules for AI
   - Perfect for personal coding style preferences and universal workflows
   - Used in features like Cursor Chat and Cmd/Ctrl+K
   
   b. **Project Rules** (Recommended):
   - Stored in `.cursor/rules` directory within projects
   - Support semantic descriptions and file pattern matching
   - Can have different rules for different parts of your project
   - Automatically included when matching files are referenced
   - Examples:
     - Framework-specific rules (e.g., SolidJS preferences for `.tsx` files)
     - Special handling for auto-generated files
     - Custom UI development patterns
     - Code style and architecture preferences for specific folders

2. **Model Context Protocol** (@Web https://docs.cursor.com/context/model-context-protocol):
   - Enhance AI understanding of your codebase
   - Provide custom context for better code generation
   - Implement domain-specific knowledge handling

3. **Custom Prompts**:
   - Guide AI behavior for specific tasks
   - Maintain consistent coding standards
   - Optimize AI responses for your workflow

## Example Global Rule

Below is an example of a powerful global rule that implements project management best practices:

```markdown
---
description: global rule to create and maintain a task list, bug wall, changelog and convo history
globs: *.md, *.mdc
---
You are a very experienced senior programmer with a strong preference for clean programming and elegant design patterns.

You diligently approach every task with K.I.S.S principles at top of mind always. Keep It Simple, Stupid - when considering a variety of solutions you will ALWAYS prioritize simplicity above all. Unnecessary complexity will compound quickly and lead to unimagineable horrors. You will consistently make extra efforts to find simple and elegant solutions.

DO NOT GIVE ME HIGH LEVEL SHIT, IF I ASK FOR FIX OR EXPLANATION, I WANT ACTUAL CODE OR EXPLANATION!!! I DON'T WANT "Here's how you can blablabla"

---

HIGH LEVEL PRINCIPLES AND GUIDELINES YOU WILL FOLLOW:

- Treat me as an expert; we are both cracked engineers and together we can change the world
- Consider new technologies and contrarian ideas, not just the conventional wisdom
- You may use high levels of speculation or prediction, just flag it for me
- Be casual unless otherwise specified
- Be terse
- Suggest solutions that I didn't think about—anticipate my needs
- Be accurate and thorough
- Generate code, corrections, and refactorings that comply with the basic principles and nomenclature.
- Split into multiple responses if one response isn't enough to answer the question.

[... continued in file ...]
```

## Getting Started

1. Clone this repository into your Cursor workspace
2. For global rules:
   - Copy desired rules to Cursor Settings > General > Rules for AI
   - These will apply to all your projects
3. For project rules:
   - Create a `.cursor/rules` directory in your project
   - Add rule files with `.mdc` extension
   - Use glob patterns to specify which files the rules apply to
4. Customize prompts and rules based on your needs
5. Set up any required MCP servers following the documentation

## Contributing

Feel free to contribute your own rules, prompts, or improvements. Rip a new branch and get after it

## Resources

- [Cursor Official Documentation](https://cursor.sh/docs)
- [Rules for AI Documentation](https://docs.cursor.com/context/rules-for-ai)
- [MCP Documentation](https://docs.cursor.com/context/model-context-protocol)
- [Cursor Discord Community](https://discord.gg/cursor) 