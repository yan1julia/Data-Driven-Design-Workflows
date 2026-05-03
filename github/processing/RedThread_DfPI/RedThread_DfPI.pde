/*
  DfPI Digital Skills - Part 2
  Red Thread / Textile / Architecture / Movement

  This sketch loads a Grasshopper OBJ model and six local datasets.
  The data controls fragment position, scale, movement, thread density,
  red-thread thickness, opacity, stitching growth, and cluster behaviour.

  Export:
  - Set EXPORT_FRAMES to true below, or press E while the sketch runs.
  - Frames are saved to output_frames/thread_frame_####.png.
  - 1800 frames at 30 fps = 60 seconds.
*/

import java.util.HashMap;
import java.util.ArrayList;
import java.io.File;

final int FPS = 30;
final int TOTAL_FRAMES = 1800;     // 60 seconds at 30 fps
final boolean LOOP_PREVIEW = false;
boolean EXPORT_FRAMES = false;

PShape objModel;
volatile boolean objReady = false;
volatile boolean objLoadFailed = false;

// The original Rhino OBJ is backed up as data/1_original_heavy.obj.
// data/1.obj is a lightweight Processing version generated from the same CSV logic.
PVector objCenter = new PVector(0, 0, 0);
float objFitScale = 0.34;
float objMinX, objMaxX, objMinY, objMaxY, objMinZ, objMaxZ;
boolean objBoundsFound = false;

Table fragmentsTable;
Table redFeaturesTable;
Table actionsTable;
Table vaTable;
Table archTable;
Table moveTable;

ArrayList<Fragment> fragments = new ArrayList<Fragment>();
ArrayList<ThreadLink> links = new ArrayList<ThreadLink>();
HashMap<String, String> actionByKeyword = new HashMap<String, String>();
HashMap<String, RedFeature> redByFile = new HashMap<String, RedFeature>();

float minX, maxX, minY, maxY, minZ, maxZ;
float minHeight, maxHeight, minTwist, maxTwist;
float minRadius, maxRadius, minRib, maxRib;
float minRedRatio, maxRedRatio, minEdge, maxEdge, minSkeleton, maxSkeleton;

float textileWeight = 1.0;
float architectureWeight = 1.0;
float movementWeight = 1.0;

void settings() {
  size(1280, 720, P3D);
  smooth(8);
}

void setup() {
  frameRate(FPS);

  loadDatasets();
  buildActionMap();
  buildRedFeatureMap();
  computeRanges();
  buildFragments();
  buildThreadLinks();

  thread("loadObjModelAsync");

  colorMode(RGB, 255, 255, 255, 255);
  perspective(PI / 3.0, float(width) / float(height), 5, 20000);

  File outputDir = new File(sketchPath("output_frames"));
  outputDir.mkdirs();
}

void loadObjModelAsync() {
  try {
    println("Loading 1.obj in background...");
    objModel = loadShape("1.obj");
    if (objModel != null) {
      objModel.disableStyle();
      objReady = true;
      println("1.obj loaded.");
    } else {
      objLoadFailed = true;
      println("1.obj could not be loaded; using procedural fragments.");
    }
  } catch (Exception e) {
    objLoadFailed = true;
    println("1.obj load failed; using procedural fragments.");
    println(e.getMessage());
  }
}

void draw() {
  float t = frameCount / float(TOTAL_FRAMES);
  if (LOOP_PREVIEW) t = (frameCount % TOTAL_FRAMES) / float(TOTAL_FRAMES);
  t = constrain(t, 0, 1);

  background(6, 7, 10);
  setupLighting(t);
  setupCamera(t);

  // A faint floor grid gives the textile network a spatial reference.
  drawGroundGrid(t);

  // The loaded OBJ is the central architectural body.
  drawLoadedObjCore(t);

  // The architectural bodies appear first as separated fragments.
  for (Fragment f : fragments) {
    f.update(t);
    f.display(t);
  }

  // Red stitching grows through the scene after the fragments establish.
  drawThreadNetwork(t);

  // A subtle front-layer data veil connects the work back to textile/skeleton logic.
  drawDataVeil(t);

  if (EXPORT_FRAMES && frameCount <= TOTAL_FRAMES) {
    saveFrame("output_frames/thread_frame_####.png");
  }

  if (!LOOP_PREVIEW && frameCount >= TOTAL_FRAMES && EXPORT_FRAMES) {
    noLoop();
  }
}

void drawLoadedObjCore(float t) {
  if (!objReady || objModel == null) return;

  pushMatrix();
  translate(0, 8 * sin(frameCount * 0.018), 0);
  rotateY(frameCount * 0.006 + t * PI);
  rotateX(-0.18 + sin(frameCount * 0.009) * 0.08);
  scale(3.1);
  translate(-objCenter.x, -objCenter.y, -objCenter.z);

  noStroke();
  fill(205, 211, 216, 95);
  specular(230, 230, 235);
  shininess(28.0);
  shape(objModel);
  popMatrix();
}

void loadDatasets() {
  fragmentsTable = loadTable("gh_20_architectural_fragments.csv", "header");
  redFeaturesTable = loadTable("red_thread_image_features.csv", "header");
  actionsTable = loadTable("api_like_design_actions.csv", "header");
  vaTable = loadTable("df_va.csv", "header");
  archTable = loadTable("df_arch.csv", "header");
  moveTable = loadTable("df_move.csv", "header");

  textileWeight = 0.75 + min(vaTable.getRowCount(), 120) / 160.0;
  architectureWeight = 0.75 + min(archTable.getRowCount(), 120) / 180.0;
  movementWeight = 0.75 + min(moveTable.getRowCount(), 120) / 150.0;
}

void buildActionMap() {
  for (TableRow row : actionsTable.rows()) {
    String keyword = cleanString(row.getString("keyword"));
    String action = cleanString(row.getString("generated_design_action"));
    if (keyword.length() > 0) {
      actionByKeyword.put(keyword, action);
    }
  }
}

void buildRedFeatureMap() {
  for (TableRow row : redFeaturesTable.rows()) {
    String fileName = cleanString(row.getString("file"));
    RedFeature rf = new RedFeature();
    rf.redRatio = getFloat(row, "red_ratio", 0.08);
    rf.edgeDensity = getFloat(row, "edge_density", 0.04);
    rf.skeletonLength = getFloat(row, "skeleton_length", 20000);
    redByFile.put(fileName, rf);
  }
}

void computeRanges() {
  minX = minY = minZ = minHeight = minTwist = minRadius = minRib = 999999;
  maxX = maxY = maxZ = maxHeight = maxTwist = maxRadius = maxRib = -999999;
  minRedRatio = minEdge = minSkeleton = 999999;
  maxRedRatio = maxEdge = maxSkeleton = -999999;

  for (TableRow row : fragmentsTable.rows()) {
    float x = getFloat(row, "x", 0);
    float y = getFloat(row, "y", 0);
    float z = getFloat(row, "z", 0);
    float h = getFloat(row, "height", 1);
    float tw = getFloat(row, "twist", 0);
    float pr = getFloat(row, "pipe_radius", 0.1);
    float rb = getFloat(row, "rib_count", 4);
    float rr = featureFor(row).redRatio;
    float ed = featureFor(row).edgeDensity;
    float sk = featureFor(row).skeletonLength;

    minX = min(minX, x); maxX = max(maxX, x);
    minY = min(minY, y); maxY = max(maxY, y);
    minZ = min(minZ, z); maxZ = max(maxZ, z);
    minHeight = min(minHeight, h); maxHeight = max(maxHeight, h);
    minTwist = min(minTwist, tw); maxTwist = max(maxTwist, tw);
    minRadius = min(minRadius, pr); maxRadius = max(maxRadius, pr);
    minRib = min(minRib, rb); maxRib = max(maxRib, rb);
    minRedRatio = min(minRedRatio, rr); maxRedRatio = max(maxRedRatio, rr);
    minEdge = min(minEdge, ed); maxEdge = max(maxEdge, ed);
    minSkeleton = min(minSkeleton, sk); maxSkeleton = max(maxSkeleton, sk);
  }
}

void buildFragments() {
  for (TableRow row : fragmentsTable.rows()) {
    Fragment f = new Fragment();
    f.id = int(getFloat(row, "fragment_id", fragments.size()));
    f.fileName = cleanString(row.getString("file"));
    f.keyword = cleanString(row.getString("keyword"));
    f.cluster = int(getFloat(row, "cluster", 0));
    f.designAction = actionByKeyword.containsKey(f.keyword) ? actionByKeyword.get(f.keyword) : "";

    float rawX = getFloat(row, "x", 0);
    float rawY = getFloat(row, "y", 0);
    float rawZ = getFloat(row, "z", 0);
    f.basePos = new PVector(
      mapSafe(rawX, minX, maxX, -460, 460),
      mapSafe(rawZ, minZ, maxZ, -160, 180),
      mapSafe(rawY, minY, maxY, -360, 360)
    );

    f.height = getFloat(row, "height", 1);
    f.twist = getFloat(row, "twist", 0);
    f.pipeRadius = getFloat(row, "pipe_radius", 0.08);
    f.ribCount = int(getFloat(row, "rib_count", 4));
    f.red = featureFor(row);

    float heightN = mapSafe(f.height, minHeight, maxHeight, 0, 1);
    float twistN = mapSafe(f.twist, minTwist, maxTwist, 0, 1);
    float radiusN = mapSafe(f.pipeRadius, minRadius, maxRadius, 0, 1);
    float skeletonN = mapSafe(f.red.skeletonLength, minSkeleton, maxSkeleton, 0, 1);

    f.modelScale = 3.0 + heightN * 5.2 + radiusN * 1.2;
    f.rotationSpeed = 0.004 + twistN * 0.025;
    f.verticalAmp = 12 + heightN * 55 + skeletonN * 30;
    f.pulseAmp = 0.015 + mapSafe(f.red.edgeDensity, minEdge, maxEdge, 0, 0.08);
    f.phase = f.id * 0.73;

    if (f.cluster == 0) {
      f.behaviourWeight = textileWeight;
      f.rotationSpeed *= 0.55;
      f.verticalAmp *= 0.70;
    } else if (f.cluster == 1) {
      f.behaviourWeight = architectureWeight;
      f.rotationSpeed *= 0.85;
      f.verticalAmp *= 0.45;
    } else {
      f.behaviourWeight = movementWeight;
      f.rotationSpeed *= 1.45;
      f.verticalAmp *= 1.25;
    }

    fragments.add(f);
  }
}

void buildThreadLinks() {
  for (int i = 0; i < fragments.size(); i++) {
    Fragment a = fragments.get(i);
    int desired = int(mapSafe(a.ribCount, minRib, maxRib, 2, 7));
    desired += int(mapSafe(a.red.edgeDensity, minEdge, maxEdge, 0, 5));

    for (int k = 1; k <= desired; k++) {
      int j = (i + k * 3 + a.cluster) % fragments.size();
      if (j == i) continue;

      Fragment b = fragments.get(j);
      if (!linkExists(i, j)) {
        ThreadLink link = new ThreadLink();
        link.a = i;
        link.b = j;
        link.delay = map(i + k, 0, fragments.size() + desired, 0.08, 0.72);
        link.thickness = 0.6 + mapSafe((a.red.redRatio + b.red.redRatio) * 0.5, minRedRatio, maxRedRatio, 0.4, 4.2);
        link.opacity = 45 + mapSafe((a.red.edgeDensity + b.red.edgeDensity) * 0.5, minEdge, maxEdge, 30, 190);
        link.waver = 12 + mapSafe((a.red.skeletonLength + b.red.skeletonLength) * 0.5, minSkeleton, maxSkeleton, 10, 105);
        link.phase = random(TWO_PI);
        links.add(link);
      }
    }
  }
}

boolean linkExists(int a, int b) {
  for (ThreadLink link : links) {
    if ((link.a == a && link.b == b) || (link.a == b && link.b == a)) return true;
  }
  return false;
}

void setupLighting(float t) {
  ambientLight(34, 36, 42);
  directionalLight(220, 224, 232, -0.25, 0.55, -0.7);
  pointLight(255, 52, 48, 420 * sin(TWO_PI * t), -260, 520 * cos(TWO_PI * t));
  lightSpecular(210, 210, 215);
}

void setupCamera(float t) {
  float orbit = TWO_PI * (0.07 + t * 0.78);
  float camRadius = 930 + sin(TWO_PI * t * 2.0) * 75;
  float camX = cos(orbit) * camRadius;
  float camZ = sin(orbit) * camRadius;
  float camY = -230 + sin(TWO_PI * t * 1.2) * 85;
  camera(camX, camY, camZ, 0, 0, 0, 0, 1, 0);
}

void drawGroundGrid(float t) {
  pushMatrix();
  stroke(60, 64, 72, 38);
  strokeWeight(1);
  noFill();
  int span = 680;
  int step = 80;
  for (int i = -span; i <= span; i += step) {
    line(i, 220, -span, i, 220, span);
    line(-span, 220, i, span, 220, i);
  }
  popMatrix();
}

void drawThreadNetwork(float t) {
  float globalGrow = smoothstep(0.08, 0.94, t);
  for (ThreadLink link : links) {
    float localGrow = smoothstep(link.delay, min(link.delay + 0.32, 0.98), t);
    localGrow *= globalGrow;
    if (localGrow <= 0.001) continue;

    Fragment a = fragments.get(link.a);
    Fragment b = fragments.get(link.b);
    PVector pa = a.currentPos.copy();
    PVector pb = b.currentPos.copy();

    float pulse = sin(frameCount * 0.035 + link.phase) * link.waver * (0.35 + localGrow);
    PVector mid = PVector.add(pa, pb).mult(0.5);
    mid.y -= 70 + pulse;
    mid.x += sin(frameCount * 0.017 + link.phase) * link.waver * 0.45;
    mid.z += cos(frameCount * 0.015 + link.phase) * link.waver * 0.45;

    stroke(232, 18, 22, link.opacity * localGrow);
    strokeWeight(link.thickness * (0.45 + localGrow * 0.9));
    noFill();
    drawGrowingCurve(pa, mid, pb, localGrow);

    // Fine secondary stitch, offset in time, creates textile layering.
    stroke(255, 92, 86, 42 * localGrow);
    strokeWeight(max(0.45, link.thickness * 0.35));
    PVector mid2 = mid.copy();
    mid2.y += 34 * sin(frameCount * 0.02 + link.phase);
    mid2.x += 22 * cos(frameCount * 0.014 + link.phase);
    drawGrowingCurve(pa, mid2, pb, max(0, localGrow - 0.12));
  }
}

void drawGrowingCurve(PVector a, PVector c, PVector b, float grow) {
  int steps = 28;
  PVector previous = quadraticPoint(a, c, b, 0);
  for (int i = 1; i <= steps; i++) {
    float u = i / float(steps);
    if (u > grow) break;
    PVector p = quadraticPoint(a, c, b, u);
    line(previous.x, previous.y, previous.z, p.x, p.y, p.z);
    previous = p;
  }
}

PVector quadraticPoint(PVector a, PVector c, PVector b, float u) {
  float inv = 1.0 - u;
  return new PVector(
    inv * inv * a.x + 2 * inv * u * c.x + u * u * b.x,
    inv * inv * a.y + 2 * inv * u * c.y + u * u * b.y,
    inv * inv * a.z + 2 * inv * u * c.z + u * u * b.z
  );
}

void drawDataVeil(float t) {
  float veilAlpha = smoothstep(0.18, 0.88, t) * 44;
  strokeWeight(1);
  noFill();
  for (int i = 0; i < fragments.size(); i++) {
    Fragment f = fragments.get(i);
    float n = mapSafe(f.red.skeletonLength, minSkeleton, maxSkeleton, 0.2, 1.0);
    stroke(180, 188, 198, veilAlpha * n);
    pushMatrix();
    translate(f.currentPos.x, f.currentPos.y, f.currentPos.z);
    rotateY(frameCount * 0.004 + f.phase);
    float r = 38 + n * 80;
    beginShape();
    for (int j = 0; j <= 24; j++) {
      float a = TWO_PI * j / 24.0;
      float wrinkle = sin(a * 5 + frameCount * 0.04 + f.phase) * 8 * n;
      vertex(cos(a) * (r + wrinkle), sin(a * 2 + f.phase) * 12, sin(a) * (r + wrinkle));
    }
    endShape();
    popMatrix();
  }
}

class Fragment {
  int id;
  int cluster;
  int ribCount;
  String fileName;
  String keyword;
  String designAction;
  PVector basePos;
  PVector currentPos = new PVector();
  RedFeature red;
  float height;
  float twist;
  float pipeRadius;
  float modelScale;
  float rotationSpeed;
  float verticalAmp;
  float pulseAmp;
  float behaviourWeight;
  float phase;

  void update(float t) {
    float emergence = smoothstep(0.0, 0.22, t);
    currentPos.set(basePos);
    currentPos.x *= lerp(1.55, 1.0, emergence);
    currentPos.z *= lerp(1.55, 1.0, emergence);
    currentPos.y += sin(frameCount * 0.025 * behaviourWeight + phase) * verticalAmp * smoothstep(0.04, 0.80, t);
    currentPos.y -= smoothstep(0.18, 1.0, t) * mapSafe(height, minHeight, maxHeight, 0, 70);
  }

  void display(float t) {
    pushMatrix();
    translate(currentPos.x, currentPos.y, currentPos.z);
    rotateY(frameCount * rotationSpeed + radians(twist) * 0.12);
    rotateX(sin(frameCount * 0.01 + phase) * 0.15);
    rotateZ(cos(frameCount * 0.007 + phase) * 0.08);

    float pulse = 1.0 + sin(frameCount * 0.04 + phase) * pulseAmp;
    float clusterScale = cluster == 0 ? 0.85 : (cluster == 1 ? 1.05 : 0.95);
    scale(modelScale * pulse * clusterScale * objFitScale);
    translate(-objCenter.x, -objCenter.y, -objCenter.z);

    noStroke();
    if (cluster == 0) {
      fill(185, 188, 188, 210);
      specular(120, 120, 120);
    } else if (cluster == 1) {
      fill(218, 222, 224, 226);
      specular(230, 230, 230);
    } else {
      fill(150, 158, 166, 205);
      specular(170, 175, 180);
    }
    shininess(18.0);
    drawProxyFragment(t);
    popMatrix();
  }

  void drawProxyFragment(float t) {
    float h = 16 + mapSafe(height, minHeight, maxHeight, 10, 58);
    float w = 10 + ribCount * 2.1;
    float d = 9 + mapSafe(pipeRadius, minRadius, maxRadius, 5, 22);

    stroke(210, 214, 220, 90);
    strokeWeight(0.8 / max(modelScale * objFitScale, 0.01));
    noFill();

    for (int i = 0; i < ribCount; i++) {
      float u = map(i, 0, max(1, ribCount - 1), -0.5, 0.5);
      pushMatrix();
      translate(u * w, sin(frameCount * 0.025 + phase + i) * 1.3, 0);
      rotateY(u * 0.9 + radians(twist) * 0.015);
      box(w * 0.16, h, d);
      popMatrix();
    }

    stroke(230, 22, 28, 130);
    strokeWeight(1.2 / max(modelScale * objFitScale, 0.01));
    for (int i = 0; i < ribCount; i++) {
      float a = TWO_PI * i / max(1, ribCount);
      float x = cos(a + frameCount * 0.01) * w * 0.72;
      float z = sin(a + frameCount * 0.01) * d * 0.72;
      line(x, -h * 0.5, z, -x, h * 0.5, -z);
    }
  }
}

class ThreadLink {
  int a;
  int b;
  float delay;
  float thickness;
  float opacity;
  float waver;
  float phase;
}

class RedFeature {
  float redRatio;
  float edgeDensity;
  float skeletonLength;
}

void computeObjNormalization() {
  objMinX = objMinY = objMinZ = 999999999;
  objMaxX = objMaxY = objMaxZ = -999999999;
  objBoundsFound = false;

  collectShapeBounds(objModel);

  if (objBoundsFound) {
    objCenter.set(
      (objMinX + objMaxX) * 0.5,
      (objMinY + objMaxY) * 0.5,
      (objMinZ + objMaxZ) * 0.5
    );
    float spanX = objMaxX - objMinX;
    float spanY = objMaxY - objMinY;
    float spanZ = objMaxZ - objMinZ;
    float largestSpan = max(spanX, max(spanY, spanZ));
    objFitScale = 42.0 / max(largestSpan, 0.00001);
  }
}

void collectShapeBounds(PShape s) {
  if (s == null) return;

  for (int i = 0; i < s.getVertexCount(); i++) {
    PVector v = s.getVertex(i);
    objMinX = min(objMinX, v.x); objMaxX = max(objMaxX, v.x);
    objMinY = min(objMinY, v.y); objMaxY = max(objMaxY, v.y);
    objMinZ = min(objMinZ, v.z); objMaxZ = max(objMaxZ, v.z);
    objBoundsFound = true;
  }

  for (int i = 0; i < s.getChildCount(); i++) {
    collectShapeBounds(s.getChild(i));
  }
}

RedFeature featureFor(TableRow row) {
  String fileName = cleanString(row.getString("file"));
  if (redByFile.containsKey(fileName)) return redByFile.get(fileName);

  RedFeature rf = new RedFeature();
  rf.redRatio = getFloat(row, "red_ratio", 0.08);
  rf.edgeDensity = getFloat(row, "edge_density", 0.04);
  rf.skeletonLength = getFloat(row, "skeleton_length", 20000);
  return rf;
}

float getFloat(TableRow row, String column, float fallback) {
  try {
    return row.getFloat(column);
  } catch (Exception e) {
    return fallback;
  }
}

String cleanString(String value) {
  if (value == null) return "";
  return trim(value).toLowerCase();
}

float mapSafe(float value, float low1, float high1, float low2, float high2) {
  if (abs(high1 - low1) < 0.00001) return (low2 + high2) * 0.5;
  return map(value, low1, high1, low2, high2);
}

float smoothstep(float edge0, float edge1, float x) {
  float u = constrain((x - edge0) / max(0.00001, edge1 - edge0), 0, 1);
  return u * u * (3.0 - 2.0 * u);
}

void keyPressed() {
  if (key == 'e' || key == 'E') {
    EXPORT_FRAMES = !EXPORT_FRAMES;
    println("Export frames: " + EXPORT_FRAMES);
  }
  if (key == 'r' || key == 'R') {
    loop();
  }
}
