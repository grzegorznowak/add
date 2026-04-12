---
name: grillme
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
disable-model-invocation: true
argument-hint: "[topic]"
allowed-tools: Read Grep Glob
---

# Grill Me

Interview me relentlessly about every aspect of this plan until
we reach a shared understanding. Walk down each branch of the design
tree resolving dependencies between decisions one by one.

If a question can be answered by researching the codebase, research and explore
the codebase instead.

For each question, provide your recommended answer.
