# Wordle Solver

Small Wordle solver. Primarily used to learn Ruby a bit better.

## Solving a problem

```shell
ruby solver.rb
```

## Testing algorith efficiency

```shell
# Create a baseline
ruby tester.rb --name baseline --small
# Run this to create full baseline: ruby tester.rb --name baseline
# Make change
# Test the change 
ruby tester.rb --name test --small
```

## Word phases

This solver does the following phases:

1. Look at all **answer** possibilities, and finds the word that has the most frequently used letters, given their 
positions.
2. When enough letters are found (3), switch to rating letters non-positionally. Also, do not give any score to letters
already known.
3. Once 3 letters are found, it tries to eliminate remaining possible answers. For example, given `?atch` is known, 
it finds a **guess** word that contains `p`, `m`, `w` for `patch`, `match`, and `watch` (ignoring `catch` and `hatch` 
because those letters are already found).
4. When only a couple words remain, just guess.
