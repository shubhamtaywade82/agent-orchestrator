---
description: Ruby Design Patterns (Refactoring.Guru Guidelines)
---

# Ruby Design Patterns Guidelines

When writing or refactoring Ruby code in this project, AI agents and engineers MUST adhere to the following design patterns and principles inspired by [Refactoring.Guru](https://refactoring.guru/design-patterns/ruby).

## Core Principles
1. **Duck Typing over Inheritance**: Ruby's dynamic nature means we favor "acts like a duck" (interfaces) over strict inheritance hierarchies unless sharing significant behavior via the **Template Method**.
2. **Mixins as Traits**: Use Ruby `module`s strategically as Mixins to compose behavior, avoiding deep and rigid class inheritance trees.

## Full Catalog of Ruby Design Patterns
Refactoring.Guru defines 22 design patterns across three categories. AI Agents working on this codebase should consider *all* these patterns when solving architectural problems.

### Creational Patterns
How to create objects while hiding the creation logic.
1. **Abstract Factory**: Lets you produce families of related objects without specifying their concrete classes.
2. **Builder**: Lets you construct complex objects step by step. The pattern allows you to produce different types and representations of an object using the same construction code. *(Currently implemented in Ares)*
3. **Factory Method**: Provides an interface for creating objects in a superclass, but allows subclasses to alter the type of objects that will be created.
4. **Prototype**: Lets you copy existing objects without making your code dependent on their classes.
5. **Singleton**: Lets you ensure that a class has only one instance, while providing a global access point to this instance.

### Structural Patterns
How classes and objects are composed to form larger structures.
6. **Adapter**: Allows objects with incompatible interfaces to collaborate.
7. **Bridge**: Lets you split a large class or a set of closely related classes into two separate hierarchies—abstraction and implementation—which can be developed independently of each other.
8. **Composite**: Lets you compose objects into tree structures and then work with these structures as if they were individual objects.
9. **Decorator**: Lets you attach new behaviors to objects by placing these objects inside special wrapper objects that contain the behaviors.
10. **Facade**: Provides a simplified interface to a library, a framework, or any other complex set of classes. *(Currently implemented in Ares)*
11. **Flyweight**: Lets you fit more objects into the available amount of RAM by sharing common parts of state between multiple objects instead of keeping all of the data in each object.
12. **Proxy**: Lets you provide a substitute or placeholder for another object. A proxy controls access to the original object, allowing you to perform something either before or after the request gets through to the original object.

### Behavioral Patterns
Algorithms and the assignment of responsibilities between objects.
13. **Chain of Responsibility**: Lets you pass requests along a chain of handlers. Upon receiving a request, each handler decides either to process the request or to pass it to the next handler in the chain. *(Currently implemented in Ares)*
14. **Command**: Turns a request into a stand-alone object that contains all information about the request. This transformation lets you pass requests as a method arguments, delay or queue a request's execution, and support undoable operations.
15. **Iterator**: Lets you traverse elements of a collection without exposing its underlying representation (list, stack, tree, etc.).
16. **Mediator**: Lets you reduce chaotic dependencies between objects. The pattern restricts direct communications between the objects and forces them to collaborate only via a mediator object.
17. **Memento**: Lets you save and restore the previous state of an object without revealing the details of its implementation.
18. **Observer**: Lets you define a subscription mechanism to notify multiple objects about any events that happen to the object they're observing.
19. **State**: Lets an object alter its behavior when its internal state changes. It appears as if the object changed its class.
20. **Strategy**: Lets you define a family of algorithms, put each of them into a separate class, and make their objects interchangeable.
21. **Template Method**: Defines the skeleton of an algorithm in the superclass but lets subclasses override specific steps of the algorithm without changing its structure. *(Currently implemented in Ares)*
22. **Visitor**: Lets you separate algorithms from the objects on which they operate.

## Currently Leveraged Patterns in Ares Orchestrator

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
