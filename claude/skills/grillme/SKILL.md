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

Ask one question at a time. For every question, show the number of
remaining questions and remaining branches in the current grilling session.

If a question can be answered by researching the codebase, research and explore
the codebase instead.

For each question, provide your recommended answer and a brief
plain-language explanation of the trade-off. Only add [easiest] or
[already there] when those labels are already known from existing context;
do not infer or research them. Otherwise omit the labels by default and
add "type 'research' to find out which option is [easiest] or [already
there]." When it helps ground the choice, include a concrete example,
short snippet, or small ASCII diagram.
