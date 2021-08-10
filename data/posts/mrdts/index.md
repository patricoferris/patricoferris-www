---
title: An Introduction to Mergeable Replicated Data Types by building a Collaborative Markdown Editor
description: Git Version Control for your programs data
draft: true
date: 2021-08-10
authors: 
  - Patrick Ferris
topics:
  - irmin
  - ocaml
reading: []
---

<!-- Introduction contextualising eberything -->

## Mergeable Data Types

Normal pieces of data in a program generally exist with some assumption that they will be accessed or modified *sequentially*. The program will not interact with the data concurrently. This sequential view of programming is incredible useful and matches the model many have whilst programming.

<!-- Discuss replication -->

Mergeable data types take a different approach based on versioned state and a so-called three-way merge function. Those familiar with [git][git] should have a good intuition for this.

```ocaml
module Set = struct
  type el = 'a
  type t = 
end
```

## Replication using Stores and Branches

## Merging Markdown


[git]: