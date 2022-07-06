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

For example, the words `tesla` and `slate` use the same letters. However, 366 words start with `s`, and 149 words 
start with `t`. Therefore, `slate` is preferred because it prefers the position of letters. 

2. When enough letters are found (3), switch to rating letters non-positionally. Also, do not give any score to letters
already known, and try to find remaining letters.
   
For example, given `?atch` is known, it finds a **guess** word that prefers `b`, `l`, `p`, `m`, `w` for `batch`, 
`patch`, `match`, and `watch` (ignoring `catch` and `hatch` because those letters are already found).

It will suggest the word `blimp` to match as many of the above as possible.

4. When only a couple words remain, just guess.
