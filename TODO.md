## TODO list

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
    - [ ] replace `glBufferData` with `glBufferSubData` when possible
        From the OpenGL reference:
        « When replacing the entire data store, consider using glBufferSubData
        rather than completely recreating the data store with glBufferData.
        This avoids the cost of reallocating the data store. »

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
- [ ] Components (re-usable laser circuits)
    - [ ] Load & save components
- [ ] Pause & Step
- [ ] Change UPS at runtime
- [ ] Labels & markers
