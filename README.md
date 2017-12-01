# othello-bash

Implementation of the Othello board game in bash shell script. Uses a combination of minmax tree parsing and weighted board positions to determine best moves. Recursively calls itself as a subprocess for each tree node evaluation. Very intense on CPU cores!!

## Usage instructions

In a Linux terminal, download the script and run it!

```bash
git clone git://github.com/markcoatsworth/othello-bash.git
cd othello-bash
./othello-bash.sh
```

## Important notes

This game is optimized to run on a 7th generation 8-core i7 processor. Running it on a laptop or a slow computer will be intolerably slow. You can work around this by reducing the game complexity in othello-bash.sh on line 52:

```bash
minmax_depth=3 # Set this to 1 on laptops and slower desktops!!
```

To determine which player goes first, adjust the game_state variable on line 

```bash
game_state="player1_turn" # Set this to "player2_turn" for computer start.
```
