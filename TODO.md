## TODO list

- [ ] Performance improvements
    - [ ] Research profiling
    - [ ] Optimize placing/deleting large amounts of entities
        That should improve loading saves.
- [ ] Allow toggling lasers
- [ ] Improve controls
- [X] Save/Load
- [X] Zoom in and out
    - [ ] Smooth zooming
- [X] Flip switches
- [X] Selection
    - [X] Move
    - [X] Clone
    - [X] Delete
- [X] Lamps
- [X] Two-sided mirrors
- [ ] Undo/Redo
- [ ] Rendering improvements
    - [ ] Map VBOs instead of using `glBufferData`
    - [ ] Alternate two VBOs when streaming data (like for entities)
        From the OpenGL reference:
        « Consider using multiple buffer objects to avoid stalling the rendering
        pipeline during data store updates. If any rendering in the pipeline
        makes reference to data in the buffer object being updated by
        glBufferSubData, especially from the specific region being updated,
        that rendering must drain from the pipeline before the data store can
        be updated. »
- [ ] UI
    - [ ] Main menu
    - [ ] Load & save menus
    - [ ] In-game interface
    - [ ] Labels & markers
- [ ] Components (re-usable laser circuits)
    - [ ] Load & save components
- [ ] Pause & Step
- [ ] Change UPS at runtime
