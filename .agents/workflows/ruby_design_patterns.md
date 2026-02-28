---
description: Ruby Design Patterns (Refactoring.Guru Guidelines)
---

# Ruby Design Patterns Guidelines

When writing or refactoring Ruby code in this project, AI agents and engineers MUST adhere to the following design patterns and principles inspired by [Refactoring.Guru](https://refactoring.guru/design-patterns/ruby).

## Core Principles
1. **Duck Typing over Inheritance**: Ruby's dynamic nature means we favor "acts like a duck" (interfaces) over strict inheritance hierarchies unless sharing significant behavior via the **Template Method**.
2. **Mixins as Traits**: Use Ruby `module`s strategically as Mixins to compose behavior, avoiding deep and rigid class inheritance trees.

## Recommended Patterns

### 1. Template Method Pattern
**When to use**: When you have multiple classes that follow the exact same algorithmic skeleton but differ in specific steps (e.g., CLI Adapters that share execution and timeout logic but differ in command structure).
**How in Ruby**: Create a base class with a public method that calls several empty or default private methods. Subclasses override only the necessary private methods.

### 2. Strategy Pattern
**When to use**: When an object needs to perform an operation in multiple different ways (e.g., selecting different LLM engines or parsing different types of diagnostics).
**How in Ruby**: Instead of massive `case/when` statements, pass a "strategy" object (or even a lambda context block) into a context class. Because of Duck Typing, they don't even need to inherit from a base strategy class.

### 3. Builder Pattern
**When to use**: When dealing with objects that require complex, multi-step initialization with many optional parameters (e.g., building complex AI prompts or HTTP request configurations).
**How in Ruby**: Implement a builder class that stores configuration state and provides chainable methods (returning `self`), culminating in a `.build` or `.to_s` call.

### 4. Facade Pattern
**When to use**: When you have a complex subsystem made of many interconnected classes (like the `Ares::Runtime` containing Planners, Selectors, Processors), and you want to provide a simple, unified interface to the client (`bin/ares`).
**How in Ruby**: Create a single class (like `Router` or an Orchestrator core) that delegates calls to the appropriate hidden subsystem classes.

### 5. Chain of Responsibility Pattern
**When to use**: When multiple objects might handle a request, and you want to decouple the sender from the receiver (e.g., an Engine Fallback sequence where if Claude fails, Codex tries, then Cursor tries).
**How in Ruby**: Create handlers that possess a reference to a `next_handler`. If a handler can process the request, it does so; otherwise, it calls `next_handler.call(request)`.
