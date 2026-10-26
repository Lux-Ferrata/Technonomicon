"""Mimir: FSRS scheduling for a PrairieLearn practice course.

Skills (graph nodes, FSRS cards) live in the course's skills/*.toml; templates
are PL questions pointing at a skill. Every day the scheduler ingests PL's
submissions into its own review log, replays FSRS from that log, plans the
day and writes it as a Homework assessment, then reloads PL from disk.
"""
