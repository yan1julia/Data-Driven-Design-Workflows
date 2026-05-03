DfPI Digital Skills - Part 2 Processing Project

Theme:
Red Thread / Textile / Architecture / Movement

Folder structure:
RedThread_DfPI/
  RedThread_DfPI.pde
  data/
    1.obj
    1_original_heavy.obj
    gh_20_architectural_fragments.csv
    red_thread_image_features.csv
    api_like_design_actions.csv
    df_va.csv
    df_arch.csv
    df_move.csv

How to run:
1. Open the Processing application.
2. Open RedThread_DfPI/RedThread_DfPI.pde.
3. Make sure the data folder stays beside the sketch file.
4. Press Run.

Note:
- data/1.obj is the lightweight Processing version, generated from the project fragment data so it can run reliably.
- data/1_original_heavy.obj is the original Rhino/Grasshopper export backup.

How the data is used:
- gh_20_architectural_fragments.csv controls fragment position, model scale, rotation speed, height movement, thread density, and cluster behaviour.
- red_thread_image_features.csv controls red line thickness, opacity, movement intensity, and stitching growth.
- api_like_design_actions.csv links keywords to conceptual behaviours.
- df_va.csv, df_arch.csv, and df_move.csv influence the textile, architecture, and movement behaviour weights.

Exporting frames:
1. In sketch.pde, set EXPORT_FRAMES to true near the top of the file.
2. Run the sketch.
3. Processing saves 1800 PNG frames into:
   RedThread_DfPI/output_frames/
4. At 30 fps, 1800 frames = 60 seconds.

Alternative export control:
- Press E while the sketch is running to turn frame export on or off.

Making a video:
Use Processing's Movie Maker tool, Adobe Premiere, After Effects, DaVinci Resolve, or ffmpeg.

ffmpeg example:
ffmpeg -framerate 30 -i output_frames/thread_frame_%04d.png -c:v libx264 -pix_fmt yuv420p red_thread_architecture.mp4
