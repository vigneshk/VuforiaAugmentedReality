/*============================================================================
Copyright (c) 2012 QUALCOMM Austria Research Center GmbH .
All Rights Reserved.
Qualcomm Confidential and Proprietary
============================================================================*/


#import "Dominoes.h"
#import "QCARutils.h"
#import "Cube.h"

#import <AudioToolbox/AudioToolbox.h>


// ----------------------------------------------------------------------------
// Constants
// ----------------------------------------------------------------------------

static const float kDominoScaleX        = 3.0f;
static const float kDominoScaleY        = 8.0f;
static const float kDominoScaleZ        = 15.0f;

static const float kDominoSpacing       = 15.0f;

static const float kGlowTextureScale    = 15.0f;
static const float kVirtualButtonScale  = 20.0f;



// ----------------------------------------------------------------------------
// Variables
// ----------------------------------------------------------------------------

ButtonOverlay* buttonOverlay;
NSArray* textures;

unsigned int shaderProgramID;
GLint vertexHandle;
GLint normalHandle;
GLint textureCoordHandle;
GLint mvpMatrixHandle;

bool displayedMessage;

unsigned long lastSystemTime;
unsigned long lastTapTime;

QCAR::Matrix44F modelViewMatrix;

TouchEvent touch1, touch2;
bool simulationRunning;
bool simulationHasRun;
bool shouldResetDominoes;
bool shouldClearDominoes;
bool shouldDeleteSelectedDomino;

Domino dominoArray[MAX_DOMINOES];
int dominoCount;
int uniqueId;

int dropStartIndex;
QCAR::Vec2F lastDropPosition(0, 0);

Domino* selectedDomino;
int selectedDominoIndex;

QCAR::Vec3F dominoBaseVertices[8];
QCAR::Vec3F dominoTransformedVerticesA[8];
QCAR::Vec3F dominoTransformedVerticesB[8];
QCAR::Vec3F dominoNormals[3];

bool shouldUpdateButton;
bool shouldAddButton;
bool shouldMoveButton;
bool shouldEnableButton;
bool shouldDisableButton;
bool shouldRemoveButton;

Domino* vbDomino;

SystemSoundID soundID;


// ----------------------------------------------------------------------------
// Setters
// ----------------------------------------------------------------------------

void dominoesSetButtonOverlay(ButtonOverlay* overlay) { buttonOverlay = overlay; }
void dominoesSetTextures(NSArray* t) { textures = t; }
void dominoesSetShaderProgramID(int spid) { shaderProgramID = spid; }
void dominoesSetVertexHandle(int vh) { vertexHandle = vh; }
void dominoesSetNormalHandle(int nh) { normalHandle = nh; }
void dominoesSetTextureCoordHandle(int tch) { textureCoordHandle = tch; }
void dominoesSetMvpMatrixHandle(int mmh) { mvpMatrixHandle = mmh; }


// ----------------------------------------------------------------------------
// Public functions
// ----------------------------------------------------------------------------

void
initializeDominoes()
{
    // Initialize the globals
    // Note: the GL context is not set up at this point
    
    dominoCount = 0;
    uniqueId = 0;
    selectedDomino = NULL;
    
    initDominoBaseVertices();
    initDominoNormals();
    
    lastSystemTime = getCurrentTimeMS();
    
    displayedMessage = false;
    
    shouldUpdateButton = false;
    shouldAddButton = false;
    shouldMoveButton = false;
    shouldEnableButton = false;
    shouldDisableButton = false;
    shouldRemoveButton = false;
    
    vbDomino = NULL;
    
    // Register callback function that gets called every time a tracking cycle 
    // has finished and we have a new AR state avaible
    //QCAR::registerCallback(&qcarUpdate);
    
    // Add a virtual button to each target, but deactivate for now
    addVirtualButton();
    disableVirtualButton();
    
    initSoundEffect();
}

bool dominoesIsSimulating()
{
    return simulationRunning;
}

bool dominoesHasDominoes()
{
    return (dominoCount > 0);
}

bool dominoesHasRun()
{
    return simulationHasRun;
}

void
renderDominoes()
{
    // Get the time delta since the last frame
    unsigned long currentSystemTime = getCurrentTimeMS();
    float dt = (currentSystemTime - lastSystemTime) / 1000.0f;
    
    // Clear the color and depth buffers
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Render the video background
    QCAR::State state = QCAR::Renderer::getInstance().begin();
    QCAR::Renderer::getInstance().drawVideoBackground();
    
    // Did we find any trackables this frame?
    if (state.getNumActiveTrackables() > 0) {
        
        // Get the first trackable
        const QCAR::Trackable* trackable = state.getActiveTrackable(0);
        
        // Cast to an image target
        if(trackable->getType() != QCAR::Trackable::IMAGE_TARGET) return;
        
        const QCAR::ImageTarget* target = static_cast<const QCAR::ImageTarget*> (trackable);
        
        // Find the virtual button, if it exists
        const QCAR::VirtualButton* button = target->getVirtualButton("startButton");
        
        if (button != NULL) {
            // If the virtual button is pressed, start the simulation
            if (button->isPressed()) {
                if (!simulationRunning) {
                    simulationRunning = true;
                }
            }
        }
        
        // Get the model view matrix
        modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(trackable->getPose());
        
        // Update the augmentation
        updateAugmentation(trackable, dt);
        // Render the augmentation
        renderAugmentation(trackable);
        
        // If this is our first time seeing the target, display a tip
        if (!displayedMessage) {
            displayMessage("Touch and drag slowly to drop a row of dominoes.");
            displayedMessage = true;
        }
    }
    
    QCAR::Renderer::getInstance().end();
    
    // Store the current time
    lastSystemTime = currentSystemTime;
}


void
dominoesTouchEvent(int actionType, int pointerId, float x, float y)
{
    TouchEvent* touchEvent;
    
    // Determine which finger this event represents
    if (pointerId == 0) {
        touchEvent = &touch1;
    } else if (pointerId == 1) {
        touchEvent = &touch2;
    } else {
        return;
    }
    
    if (actionType == ACTION_DOWN) {
        // On touch down, reset the following:
        touchEvent->lastX = x;
        touchEvent->lastY = y;
        touchEvent->startX = x;
        touchEvent->startY = y;
        touchEvent->startTime = getCurrentTimeMS();
        touchEvent->didTap = false;
    } else {
        // Store the last event's position
        touchEvent->lastX = touchEvent->x;
        touchEvent->lastY = touchEvent->y;
    }
    
    // Store the lifetime of the touch, used for tap recognition
    unsigned long time = getCurrentTimeMS();
    touchEvent->dt = time - touchEvent->startTime;
    
    // Store the distance squared from the initial point, for tap recognition
    float dx = touchEvent->lastX - touchEvent->startX;
    float dy = touchEvent->lastY - touchEvent->startY;
    touchEvent->dist2 = dx * dx + dy * dy;
    
    if (actionType == ACTION_UP) {
        // On touch up, this touch is no longer active
        touchEvent->isActive = false;
        
        // Determine if this touch up ends a tap gesture
        // The tap must be quick and localized
        if (touchEvent->dt < MAX_TAP_TIMER && touchEvent->dist2 < MAX_TAP_DISTANCE2) {
            touchEvent->didTap = true;
            touchEvent->tapX = touchEvent->startX;
            touchEvent->tapY = touchEvent->startY;
        }
    } else {
        // On touch down or move, this touch is active
        touchEvent->isActive = true;
    }
    
    // Set the touch information for this event
    touchEvent->actionType = actionType;
    touchEvent->pointerId = pointerId;
    touchEvent->x = x;
    touchEvent->y = y;
}


void
dominoesStart()
{
    // Start the simulation
    simulationRunning = true;
    
    // Clear the selected domino
    setSelectedDomino(NULL);
}


void
dominoesReset()
{
    // Stop the simulation
    simulationRunning = false;
    simulationHasRun = false;
    
    // Reset the dominoes on the next update, since this is a different thread
    shouldResetDominoes = true;
    
    // Clear the selected domino
    setSelectedDomino(NULL);
}


void
dominoesClear()
{
    // Stop the simulation
    simulationRunning = false;
    simulationHasRun = false;
    
    // Clear the dominoes on the next update, since this is a different thread
    shouldClearDominoes = true;
    
    // Clear the selected domino
    setSelectedDomino(NULL);
}


void
dominoesDelete()
{
    // Delete the selected domino on the next update, since this is a different thread
    shouldDeleteSelectedDomino = true;
}



// ----------------------------------------------------------------------------
// Sound and GUI
// ----------------------------------------------------------------------------

void
initSoundEffect()
{
    NSString* path = [[NSBundle mainBundle] pathForResource:@"domino_tap" ofType:@"wav"];
    NSURL* filePath = [NSURL fileURLWithPath:path isDirectory:NO];
    AudioServicesCreateSystemSoundID((CFURLRef) filePath, &soundID);
}


void
playSoundEffect()
{
    AudioServicesPlaySystemSound(soundID);
}


void
showDeleteButton()
{
    [buttonOverlay performSelectorOnMainThread:@selector(showDeleteButton) withObject:buttonOverlay waitUntilDone:YES];
}


void
hideDeleteButton()
{
    [buttonOverlay performSelectorOnMainThread:@selector(hideDeleteButton) withObject:buttonOverlay waitUntilDone:YES];
}


void
displayMessage(const char* message)
{
    [buttonOverlay performSelectorOnMainThread:@selector(showMessage:) withObject:[NSString stringWithUTF8String:message] waitUntilDone:NO];
}

void
updateButtonStatus()
{
    [buttonOverlay performSelectorOnMainThread:@selector(updateButtonStatus) withObject:nil waitUntilDone:NO];
}





// ----------------------------------------------------------------------------
// Demo update and rendering
// ----------------------------------------------------------------------------

void
updateAugmentation(const QCAR::Trackable* trackable, float dt)
{
    // Respond to a reset dominoes request
    if (shouldResetDominoes) {
        resetDominoes();
        shouldResetDominoes = false;
    }
    
    // Respond to a clear dominoes request
    if (shouldClearDominoes) {
        clearDominoes();
        shouldClearDominoes = false;
    }
    
    // Respond to a delete selected domino request
    if (shouldDeleteSelectedDomino) {
        deleteSelectedDomino();
        shouldDeleteSelectedDomino = false;
    }
    
    if (simulationRunning) {
        
        // If the simulation is running and there is at least one domino:
        if (dominoCount > 0) {
            Domino* domino = &dominoArray[0];
            if (domino->state == DOMINO_STANDING) {
                // Tip the first domino
                domino->state = DOMINO_FALLING;
            }
            // Run the simulation
            if (runSimulation(domino, dt) == false)
            {
                // the above returns false if no more dominoes falling
                simulationRunning = false;
                simulationHasRun = true;
            }
        }
        
    } else {
        // Simulation is not running, handle touches
        handleTouches();
    }
    
    // ensure UI is up to date
    updateButtonStatus();
}


void
handleTouches()
{
    // If there is a new tap that we haven't handled yet:
    if (touch1.didTap && touch1.startTime > lastTapTime) {
        
        // Find the start and end points in world space for the tap
        // These will lie on the near and far plane and can be used for picking
        QCAR::Vec3F intersection, lineStart, lineEnd;
        projectScreenPointToPlane(QCAR::Vec2F(touch1.tapX, touch1.tapY), QCAR::Vec3F(0, 0, 0), QCAR::Vec3F(0, 0, 1), intersection, lineStart, lineEnd);
        
        Domino* domino;
        Domino* selected = NULL;
        
        // For each domino, check for intersection with our picking line
        for (int i = 0; i < dominoCount; i++) {
            domino = &dominoArray[i];
            bool intersection = checkIntersectionLine(domino->pickingTransform, lineStart, lineEnd);
            if (intersection) {
                selected = domino;
                selectedDominoIndex = i;
                break;
            }
        }
        
        if (selected == NULL && selectedDomino == NULL) {
            // We did not pick a new domino, and do not have a currently selected domino to deselect
            // Try to drop a new domino at the tap's intersection point with the ground plane
            QCAR::Vec2F position(intersection.data[0], intersection.data[1]);
            if (canDropDomino(position)) {
                dropDomino(position);
            }
            
        } else {
            // If selected is NULL, this will deselect the currently selected domino
            // If selected is not NULL, this will select a new domino
            setSelectedDomino(selected);
        }
        
        // Store the timestamp for this tap so we know we've handled it
        lastTapTime = touch1.startTime;
        
    } else if (touch1.isActive) {
        
        // There was not a tap, but the touch is active
        // Ignore the touch if it might still turn into a tap
        if (touch1.dt > MAX_TAP_TIMER || touch1.dist2 > MAX_TAP_DISTANCE2) {
            
            if (selectedDomino != NULL) {
                // There is a selected domino, so use this touch to rotate it
                
                float dx = touch1.x - touch1.lastX;
                selectedDomino->pivotAngle += dx;
                while (selectedDomino->pivotAngle < -180.0f) selectedDomino->pivotAngle += 360.0f;
                while (selectedDomino->pivotAngle > 180.0f) selectedDomino->pivotAngle -= 360.0f;
                
                // Be sure to update both the main transform and picking transform when the pivot changes
                updateDominoTransform(selectedDomino);
                updatePickingTransform(selectedDomino);
                
            } else {
                // There is not a selected domino, so use this touch to drop new dominoes
                
                // Find the interection point of the touch with the ground plane
                QCAR::Vec3F intersection, lineStart, lineEnd;
                projectScreenPointToPlane(QCAR::Vec2F(touch1.x, touch1.y), QCAR::Vec3F(0, 0, 0), QCAR::Vec3F(0, 0, 1), intersection, lineStart, lineEnd);
                
                // Try to drop a domino
                QCAR::Vec2F position(intersection.data[0], intersection.data[1]);
                if (canDropDomino(position)) {
                    dropDomino(position);
                }
            }
        }
        
    } else {
        // Touch is not active
        // Mark the drop index for the next run of dominoes
        dropStartIndex = dominoCount;
    }
}


void
renderAugmentation(const QCAR::Trackable* trackable)
{
    const Texture* const dominoTexture = [textures objectAtIndex:0];
    const Texture* const greenGlowTexture = [textures objectAtIndex:1];
    const Texture* const blueGlowTexture = [textures objectAtIndex:2];
    
#ifdef USE_OPENGL1
    // Set GL11 flags
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
    glTexCoordPointer(2, GL_FLOAT, 0, (const GLvoid*) &cubeTexCoords[0]);
    glVertexPointer(3, GL_FLOAT, 0, (const GLvoid*) &cubeVertices[0]);
    glNormalPointer(GL_FLOAT, 0,  (const GLvoid*) &cubeNormals[0]);
    
    glEnable(GL_TEXTURE_2D);
    glDisable(GL_LIGHTING);
    
    // Load projection matrix
    glMatrixMode(GL_PROJECTION);
    glLoadMatrixf(projectionMatrix.data);
    
    // Load model view matrix
    glMatrixMode(GL_MODELVIEW);
    glLoadMatrixf(modelViewMatrix.data);
#else
    // Bind shader program
    glUseProgram(shaderProgramID);
    
    // Set GL20 flags
    glEnableVertexAttribArray(vertexHandle);
    glEnableVertexAttribArray(normalHandle);
    glEnableVertexAttribArray(textureCoordHandle);
    
    glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*) &cubeVertices[0]);
    glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0, (const GLvoid*) &cubeNormals[0]);
    glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, (const GLvoid*) &cubeTexCoords[0]);
#endif
    
    glEnable(GL_DEPTH_TEST);
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glActiveTexture(GL_TEXTURE0);

    // Render a green glow under the first domino, unless it is selected
    if (dominoCount > 0 && (selectedDomino == NULL || selectedDominoIndex != 0)) {
        Domino* domino = &dominoArray[0];
        QCAR::Matrix44F transform = SampleMath::Matrix44FIdentity();
        float* transformPtr = &transform.data[0];
        
        ShaderUtils::translatePoseMatrix(domino->position.data[0], domino->position.data[1], 0.0f, transformPtr);
        ShaderUtils::scalePoseMatrix(kGlowTextureScale, kGlowTextureScale, 0.0f, transformPtr);
        
        glBindTexture(GL_TEXTURE_2D, greenGlowTexture.textureID);
        renderCube(transformPtr);
    }
    
    // Render a glow under the selected domino
    if (selectedDomino != NULL) {
        Domino* domino = selectedDomino;
        QCAR::Matrix44F transform = SampleMath::Matrix44FIdentity();
        float* transformPtr = &transform.data[0];
        
        ShaderUtils::translatePoseMatrix(domino->position.data[0], domino->position.data[1], 0.0f, transformPtr);
        ShaderUtils::scalePoseMatrix(kGlowTextureScale, kGlowTextureScale, 0.0f, transformPtr);
        
        glBindTexture(GL_TEXTURE_2D, blueGlowTexture.textureID);
        renderCube(transformPtr);
    }
    
    glDisable(GL_BLEND);
    
    // Render the dominoes
    glBindTexture(GL_TEXTURE_2D, dominoTexture.textureID);
    for (int i = 0; i < dominoCount; i++) {
        Domino* domino = &dominoArray[i];
        renderCube(&domino->transform.data[0]);
    }
    
    ShaderUtils::checkGlError("Dominoes renderFrame");
    
    glDisable(GL_DEPTH_TEST);
    
#ifdef USE_OPENGL1        
    glDisable(GL_TEXTURE_2D);
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_NORMAL_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
#else
    glDisableVertexAttribArray(vertexHandle);
    glDisableVertexAttribArray(normalHandle);
    glDisableVertexAttribArray(textureCoordHandle);
#endif
}


void
renderCube(float* transform)
{
    // Render a cube with the given transform
    // Assumes prior GL setup
    
#ifdef USE_OPENGL1
    glPushMatrix();
    glMultMatrixf(transform);
    glDrawElements(GL_TRIANGLES, NUM_CUBE_INDEX, GL_UNSIGNED_SHORT, (const GLvoid*) &cubeIndices[0]);
    glPopMatrix();
#else
    QCAR::Matrix44F modelViewProjection, objectMatrix;
    ShaderUtils::multiplyMatrix(&modelViewMatrix.data[0], transform, &objectMatrix.data[0]);
    ShaderUtils::multiplyMatrix(&[QCARutils getInstance].projectionMatrix.data[0], &objectMatrix.data[0], &modelViewProjection.data[0]);
    glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE, (GLfloat*)&modelViewProjection.data[0]);
    glDrawElements(GL_TRIANGLES, NUM_CUBE_INDEX, GL_UNSIGNED_SHORT, (const GLvoid*) &cubeIndices[0]);
#endif
}



// ----------------------------------------------------------------------------
// Virtual buttons
// ----------------------------------------------------------------------------

void
virtualButtonOnUpdate(QCAR::State& state)
{
    if (shouldUpdateButton)
    {
        QCARutils *qUtils = [QCARutils getInstance];
    
        // Update runs in the tracking thread therefore it is guaranteed that the tracker is
        // not doing anything at this point. => Reconfiguration is possible.
        
        // Get the image tracker:
        QCAR::ImageTarget* target = [qUtils getImageTarget:0];
        
        [qUtils allowDataSetModification];
        
        // Get the virtual button we created earlier, if it exists
        QCAR::VirtualButton* button = target->getVirtualButton("startButton");
        
        if (shouldAddButton && button == NULL)
        {
            QCAR::Rectangle vbRectangle(0, 0, 0, 0);
            
            // Create the virtual button
            button = target->createVirtualButton("startButton", vbRectangle);
            shouldAddButton = false;
        }
        
        if (shouldMoveButton && button != NULL && dominoCount > 0)
        {
            // Create a new rectangle for the virtual button
            // This should move the button directly under the given domino
            float left = vbDomino->position.data[0] - kVirtualButtonScale;
            float right = vbDomino->position.data[0] + kVirtualButtonScale;
            float top = vbDomino->position.data[1] + kVirtualButtonScale;
            float bottom = vbDomino->position.data[1] - kVirtualButtonScale;
            
            QCAR::Rectangle vbRectangle(left, top, right, bottom);
            
            // Move the virtual button
            button->setArea(vbRectangle);
            shouldMoveButton = false;
        }
        
        if (shouldEnableButton && button != NULL)
        {
            // Enable the virtual button
            button->setEnabled(true);
            shouldEnableButton = false;
        }
        
        if (shouldDisableButton && button != NULL)
        {
            // Disable the virtual button
            button->setEnabled(false);
            shouldDisableButton = false;
        }
        
        if (shouldRemoveButton && button != NULL)
        {
            // Destroy the virtual button
            target->destroyVirtualButton(button);
            shouldRemoveButton = false;
        }
        
        [qUtils saveDataSetModifications];
        shouldUpdateButton = false;
    }
}


void
addVirtualButton()
{
    shouldAddButton = true;
    shouldUpdateButton = true;
}


void
removeVirtualButton()
{
    shouldRemoveButton = true;
    shouldUpdateButton = true;
}


void
moveVirtualButton(Domino* domino)
{
    vbDomino = domino;
    shouldMoveButton = true;
    shouldUpdateButton = true;
}


void
enableVirtualButton()
{
    shouldEnableButton = true;
    shouldUpdateButton = true;
}


void
disableVirtualButton()
{
    shouldDisableButton = true;
    shouldUpdateButton = true;
}



// ----------------------------------------------------------------------------
// Domino initialization
// ----------------------------------------------------------------------------

void
initDominoBaseVertices()
{
    // Initialize a set of vertices describing the unit cube
    
    dominoBaseVertices[0] = QCAR::Vec3F(1.0f, 1.0f, 1.0f);
    dominoBaseVertices[1] = QCAR::Vec3F(-1.0f, 1.0f, 1.0f);
    dominoBaseVertices[2] = QCAR::Vec3F(1.0f, -1.0f, 1.0f);
    dominoBaseVertices[3] = QCAR::Vec3F(-1.0f, -1.0f, 1.0f);
    dominoBaseVertices[4] = QCAR::Vec3F(1.0f, 1.0f, -1.0f);
    dominoBaseVertices[5] = QCAR::Vec3F(-1.0f, 1.0f, -1.0f);
    dominoBaseVertices[6] = QCAR::Vec3F(1.0f, -1.0f, -1.0f);
    dominoBaseVertices[7] = QCAR::Vec3F(-1.0f, -1.0f, -1.0f);
}


void
initDominoNormals()
{
    // Initialize a set of normals for the unit cube
    
    dominoNormals[0] = QCAR::Vec3F(1, 0, 0);
    dominoNormals[1] = QCAR::Vec3F(0, 1, 0);
    dominoNormals[2] = QCAR::Vec3F(0, 0, 1);
}



// ----------------------------------------------------------------------------
// Domino positioning
// ----------------------------------------------------------------------------

bool
canDropDomino(QCAR::Vec2F position)
{
    Domino* domino;
    bool isClear = false;
    float dist = SampleMath::Vec2FDist(position, lastDropPosition);
    
    // Domino must be a certain distance from the last dropped domino
    if (dist > kDominoSpacing) {
        isClear = true;
        // Domino must be a certain distance from each other domino
        for (int i = 0; i < dominoCount; i++) {
            domino = &dominoArray[i];
            dist = SampleMath::Vec2FDist(position, domino->position);
            if (dist < kDominoSpacing) {
                isClear = false;
            }
        }
    }
    
    return isClear;
}


void
dropDomino(QCAR::Vec2F position)
{
    // If we've reached the max domino count, return
    if (dominoCount == MAX_DOMINOES) {
        return;
    }
    
    // Calculate a pivot angle based on the last domino's position
    float angle = 0.0f;
    if (dominoCount > 0) {
        QCAR::Vec2F d = SampleMath::Vec2FSub(position, lastDropPosition);
        angle = atan2(d.data[1], d.data[0]);
        angle *= 180.0f / M_PI;
        
        while (angle < -180.0f) angle += 360.0f;
        while (angle > 180.0f) angle -= 360.0f;
    }
    
    // Get the next available domino structure
    Domino* domino = &dominoArray[dominoCount];
    
    // Initialize the domino
    domino->id = uniqueId;
    domino->state = DOMINO_STANDING;
    domino->restingFrameCount = 0;
    
    domino->position = position;
    domino->pivotAngle = angle;
    domino->tiltAngle = 0.0f;
    
    // Calculate the initial transforms from the position and pivot
    updateDominoTransform(domino);
    updatePickingTransform(domino);
    
    // Initialze a set of neighboring dominoes, based on distance
    // This will be used to limit the number of collision checks needed during simulation
    domino->neighborList = NULL;
    Domino* otherDomino;
    float dist;
    for (int i = 0; i < dominoCount; i++) {
        otherDomino = &dominoArray[i];
        dist = SampleMath::Vec2FDist(domino->position, otherDomino->position);
        if (dist < (kDominoSpacing * 2)) {
            LLNode* newNode = new LLNode();
            newNode->id = otherDomino->id;
            newNode->next = domino->neighborList;
            domino->neighborList = newNode;
            
            newNode = new LLNode();
            newNode->id = domino->id;
            newNode->next = otherDomino->neighborList;
            otherDomino->neighborList = newNode;
        }
    }
    
    // If this is the first domino placed, move the virtual button under it
    // The virtual button is used to start the simulation when a finger "touches" the first domino
    if (dominoCount == 0) {
        moveVirtualButton(domino);
        enableVirtualButton();
    }
    
    // If this is the second domino placed, pivot the first domino in the run
    // such that it will tilt towards the second
    if (dominoCount == (dropStartIndex + 1)) {
        Domino* firstDomino = &dominoArray[dropStartIndex];
        firstDomino->pivotAngle = domino->pivotAngle;
        updateDominoTransform(firstDomino);
        updatePickingTransform(firstDomino);
    }
    
    // Increment the domino counter and the unique id counter
    // The domino counter will increase and decrease during the lifetime of the application
    // The unique id counter will only increase
    dominoCount++;
    uniqueId++;
    
    // Store the current domino position for later use
    lastDropPosition = position;
}


void
updateDominoTransform(Domino* domino)
{
    // Reset the domino transform to the identity matrix
    domino->transform = SampleMath::Matrix44FIdentity();
    float* transformPtr = &domino->transform.data[0];
    
    // The following transformations happen in reverse order
    // We want to scale the domino, tip the domino (on its leading edge), pivot and then position the domino
    ShaderUtils::translatePoseMatrix(domino->position.data[0], domino->position.data[1], 0.0f, transformPtr);
    ShaderUtils::rotatePoseMatrix(domino->pivotAngle, 0, 0, 1, transformPtr);
    ShaderUtils::translatePoseMatrix(kDominoScaleX, 0.0f, 0.0f, transformPtr);
    ShaderUtils::rotatePoseMatrix(domino->tiltAngle, 0, 1, 0, transformPtr);
    ShaderUtils::translatePoseMatrix(-kDominoScaleX, 0.0f, kDominoScaleZ, transformPtr);
    ShaderUtils::scalePoseMatrix(kDominoScaleX, kDominoScaleY, kDominoScaleZ, transformPtr);
}


void
updatePickingTransform(Domino* domino)
{
    // Reset the picking transform to the identity matrix
    domino->pickingTransform = SampleMath::Matrix44FIdentity();
    float* transformPtr = &domino->pickingTransform.data[0];
    
    // The following transformations happen in reverse order
    // For picking, we want a slightly wider target to improve responsiveness
    // We can also skip the tilting transformation, since picking only occurs when the dominoes are upright
    ShaderUtils::translatePoseMatrix(domino->position.data[0], domino->position.data[1], 0.0f, transformPtr);
    ShaderUtils::rotatePoseMatrix(domino->pivotAngle, 0, 0, 1, transformPtr);
    ShaderUtils::translatePoseMatrix(0.0f, 0.0f, kDominoScaleZ, transformPtr);
    ShaderUtils::scalePoseMatrix(kDominoScaleX * 2, kDominoScaleY, kDominoScaleZ, transformPtr);
}



// ----------------------------------------------------------------------------
// Domino simulation
// ----------------------------------------------------------------------------

bool
runSimulation(Domino* domino, float dt)
{
    // The simulation is run recursively
    // This allows dominoes at the end of the line to tilt before dominoes towards the front
    
    // Prepare the recursive call
    LLNode* node = domino->neighborList;
    Domino* otherDomino;
    bool stillFalling = NO; // keep a record of dominoes still falling
    
    while (node != NULL) {
        
        // For each neighbor, if that neighbor is:
        //   a) not NULL (could be NULL if it has been deleted by the user)
        //   b) not standing (i.e. already tipped)
        //   c) tipped by the current domino
        // Then we recur, first running the simulation for that neighbor
        
        otherDomino = getDominoById(node->id);
        if (otherDomino != NULL && otherDomino->state != DOMINO_STANDING && otherDomino->tippedBy == domino->id) {
            if (runSimulation(otherDomino, dt) == true)
            {
                // the above returns true if dominoes are still falling
                stillFalling = true;
            }
        }
        node = node->next;
    }
    
    // If the domino is resting, we can skip the rest of its simulation
    if (domino->state == DOMINO_RESTING) {
        return stillFalling;
    }
    
    // Tilt the domino using the time delta for this frame
    float originalTilt = domino->tiltAngle;
    domino->tiltAngle += dt * DOMINO_TILT_SPEED;
    domino->tiltAngle = MIN(domino->tiltAngle, 90.0f);
    updateDominoTransform(domino);
    
    // Check for collisions with its neighbors
    node = domino->neighborList;
    
    while (node != NULL) {
        otherDomino = getDominoById(node->id);
        if (otherDomino == NULL) {
            // Neighbor could be NULL if it was deleted by the user
            node = node->next;
            continue;
        }
        
        // Check for an intersection between the two dominoes
        bool collision = checkIntersection(domino->transform, otherDomino->transform);
        
        if (collision) {
            
            if (otherDomino->state == DOMINO_STANDING) {
                // If this is a first-time collision, play a sound effect
                playSoundEffect();
                
                // The other domino might be facing the wrong way
                // Rotate it to tip in the right direction
                adjustPivot(domino, otherDomino);
                
                // Set the other domino to falling and this domino as the cause
                otherDomino->state = DOMINO_FALLING;
                otherDomino->tippedBy = domino->id;
            }
            
            // Resolve the collision of the two dominoes
            // After this step the dominoes should no longer be colliding
            handleCollision(domino, otherDomino, originalTilt);
        }
        
        node = node->next;
    }
    
    // ensure that dominoes fallen onto stoney ground get accounted for
    if (domino->tiltAngle == 90.0f)
        domino->state = DOMINO_RESTING;
    
    // return whether any dominoes are still falling
    return (stillFalling || (domino->state == DOMINO_FALLING));
}


void
handleCollision(Domino* domino, Domino* otherDomino, float originalTilt)
{
    // The goal of this function is to tweak the tilt value of the domino
    // such that it is close to but not touching the other domino
    
    // For simplicity's sake, we will use a bisection search to iteratively get closer to this goal
    // This is not the most efficient method, but is simple to write and understand
    
    int iteration = 0;
    
    // If we are here, the dominoes are already colliding
    bool collision = true;
    
    // On the left, we have a tilt at which there is no collision
    // On the right, we have a new tilt which does cause a collision
    float left = originalTilt;
    float right = domino->tiltAngle;
    float midpoint;
    
    // For a max of 10 iterations, attempt to find a tilt that bridges the collision line
    // within one degree and that is finally not colliding
    while (iteration < 10 && (fabs(right - left) > 1.0f || collision)) {
        
        midpoint = (right + left) / 2.0f;
        
        domino->tiltAngle = midpoint;
        updateDominoTransform(domino);
        collision = checkIntersection(domino->transform, otherDomino->transform);
        
        if (collision) {
            right = midpoint;
        } else {
            left = midpoint;
        }
        
        iteration++;
    }
    
    // If there is still a collision, we could do no better than the original tilt
    if (collision) {
        domino->tiltAngle = originalTilt;
        updateDominoTransform(domino);
    }
    
    // If we ran for the full 10 iterations, we must not have moved very far
    // After five consecutive rounds of not moving we will decide that this domino is resting
    if (iteration == 10) {
        domino->restingFrameCount++;
        if (domino->restingFrameCount == 5) {
            domino->state = DOMINO_RESTING;
        }
    } else {
        domino->restingFrameCount = 0;
    }
}


void
adjustPivot(Domino* domino, Domino* otherDomino)
{
    // Adjust the pivot of the second domino such that it will tilt
    // correctly in relation to the first domino
    
    float pivotA = domino->pivotAngle;
    float pivotB = otherDomino->pivotAngle;
    
    float dPivot = fabs(pivotA - pivotB);
    if (dPivot > 180.0f) {
        dPivot = 360.0f - dPivot;
    }
    
    if (dPivot > 90.0f) {
        otherDomino->pivotAngle += 180.0f;
        if (otherDomino->pivotAngle > 180.0f) {
            otherDomino->pivotAngle -= 360.0f;
        }
        
        // Always update the transforms when the pivot has changed
        updateDominoTransform(otherDomino);
        updatePickingTransform(otherDomino);
    }
}


Domino*
getDominoById(int id)
{
    // Retreive the domino with the given unique id
    // or return NULL if one is not found
    
    Domino* domino;
    for (int i = 0; i < dominoCount; i++) {
        domino = &dominoArray[i];
        if (domino->id == id) {
            return domino;
        }
    }
    
    return NULL;
}



// ----------------------------------------------------------------------------
// Domino management
// ----------------------------------------------------------------------------

void
resetDominoes()
{
    // Set all the dominoes upright and reset their resting state
    
    Domino* domino;
    
    for (int i = 0; i < dominoCount; i++) {
        domino = &dominoArray[i];
        domino->state = DOMINO_STANDING;
        domino->tiltAngle = 0.0f;
        domino->restingFrameCount = 0;
        updateDominoTransform(domino);
    }
}


void
clearDominoes()
{
    // Delete all the dominoes
    
    Domino* domino;
    LLNode* node;
    LLNode* temp;
    int count;
    for (int i = 0; i < dominoCount; i++) {
        domino = &dominoArray[i];
        node = domino->neighborList;
        count = 0;
        while (node != NULL) {
            temp = node->next;
            delete node;
            node = temp;
            count++;
        }
    }
    
    dominoCount = 0;
    
    disableVirtualButton();
}


void
setSelectedDomino(Domino* domino)
{
    if (domino == NULL && selectedDomino != NULL) {
        // If we are deselecting a domino, hide the delete button
        hideDeleteButton();
    } else if (domino != NULL && selectedDomino == NULL) {
        // If we are selecting a domino (and didn't already have one selected), show the delete button
        showDeleteButton();
    }
    selectedDomino = domino;
}


void
deleteSelectedDomino()
{
    // Delete the selected domino
    
    if (selectedDominoIndex != dominoCount - 1) {
        void* p1 = &dominoArray[selectedDominoIndex];
        void* p2 = &dominoArray[selectedDominoIndex+1];
        memmove(p1, p2, (dominoCount - selectedDominoIndex) * sizeof(Domino));
    }
    dominoCount--;
    setSelectedDomino(NULL);
    
    if (dominoCount > 0) {
        moveVirtualButton(&dominoArray[0]);
    } else {
        disableVirtualButton();
    }
}



// ----------------------------------------------------------------------------
// Touch projection
// ----------------------------------------------------------------------------

void
projectScreenPointToPlane(QCAR::Vec2F point, QCAR::Vec3F planeCenter, QCAR::Vec3F planeNormal,
                          QCAR::Vec3F &intersection, QCAR::Vec3F &lineStart, QCAR::Vec3F &lineEnd)
{
    QCARutils *qUtils = [QCARutils getInstance];
    
    // Window Coordinates to Normalized Device Coordinates
    QCAR::VideoBackgroundConfig config = QCAR::Renderer::getInstance().getVideoBackgroundConfig();
    
    float halfScreenWidth = qUtils.viewSize.height / 2.0f; // note use of height for width
    float halfScreenHeight = qUtils.viewSize.width / 2.0f; // likewise
    
    float halfViewportWidth = config.mSize.data[0] / 2.0f;
    float halfViewportHeight = config.mSize.data[1] / 2.0f;
    
    float x = (qUtils.contentScalingFactor * point.data[0] - halfScreenWidth) / halfViewportWidth;
    float y = (qUtils.contentScalingFactor * point.data[1] - halfScreenHeight) / halfViewportHeight * -1;
    
    QCAR::Vec4F ndcNear(x, y, -1, 1);
    QCAR::Vec4F ndcFar(x, y, 1, 1);
    
    // Normalized Device Coordinates to Eye Coordinates
    QCAR::Matrix44F projectionMatrix = [QCARutils getInstance].projectionMatrix;
    QCAR::Matrix44F inverseProjMatrix = SampleMath::Matrix44FInverse(projectionMatrix);
    
    QCAR::Vec4F pointOnNearPlane = SampleMath::Vec4FTransform(ndcNear, inverseProjMatrix);
    QCAR::Vec4F pointOnFarPlane = SampleMath::Vec4FTransform(ndcFar, inverseProjMatrix);
    pointOnNearPlane = SampleMath::Vec4FDiv(pointOnNearPlane, pointOnNearPlane.data[3]);
    pointOnFarPlane = SampleMath::Vec4FDiv(pointOnFarPlane, pointOnFarPlane.data[3]);
    
    // Eye Coordinates to Object Coordinates
    QCAR::Matrix44F inverseModelViewMatrix = SampleMath::Matrix44FInverse(modelViewMatrix);
    
    QCAR::Vec4F nearWorld = SampleMath::Vec4FTransform(pointOnNearPlane, inverseModelViewMatrix);
    QCAR::Vec4F farWorld = SampleMath::Vec4FTransform(pointOnFarPlane, inverseModelViewMatrix);
    
    lineStart = QCAR::Vec3F(nearWorld.data[0], nearWorld.data[1], nearWorld.data[2]);
    lineEnd = QCAR::Vec3F(farWorld.data[0], farWorld.data[1], farWorld.data[2]);
    linePlaneIntersection(lineStart, lineEnd, planeCenter, planeNormal, intersection);
}


bool
linePlaneIntersection(QCAR::Vec3F lineStart, QCAR::Vec3F lineEnd,
                      QCAR::Vec3F pointOnPlane, QCAR::Vec3F planeNormal,
                      QCAR::Vec3F &intersection)
{
    QCAR::Vec3F lineDir = SampleMath::Vec3FSub(lineEnd, lineStart);
    lineDir = SampleMath::Vec3FNormalize(lineDir);
    
    QCAR::Vec3F planeDir = SampleMath::Vec3FSub(pointOnPlane, lineStart);
    
    float n = SampleMath::Vec3FDot(planeNormal, planeDir);
    float d = SampleMath::Vec3FDot(planeNormal, lineDir);
    
    if (fabs(d) < 0.00001) {
        // Line is parallel to plane
        return false;
    }
    
    float dist = n / d;
    
    QCAR::Vec3F offset = SampleMath::Vec3FScale(lineDir, dist);
    intersection = SampleMath::Vec3FAdd(lineStart, offset);
    
    return true;
}



// ----------------------------------------------------------------------------
// Collision detection
// ----------------------------------------------------------------------------

bool
checkIntersection(QCAR::Matrix44F transformA, QCAR::Matrix44F transformB)
{
    // Use the separating axis theorem to determine whether or not
    // two object-oriented bounding boxes are intersecting
    
    transformA = SampleMath::Matrix44FTranspose(transformA);
    transformB = SampleMath::Matrix44FTranspose(transformB);
    
    QCAR::Vec3F normalA1 = SampleMath::Vec3FTransformNormal(dominoNormals[0], transformA);
    QCAR::Vec3F normalA2 = SampleMath::Vec3FTransformNormal(dominoNormals[1], transformA);
    QCAR::Vec3F normalA3 = SampleMath::Vec3FTransformNormal(dominoNormals[2], transformA);
    
    QCAR::Vec3F normalB1 = SampleMath::Vec3FTransformNormal(dominoNormals[0], transformB);
    QCAR::Vec3F normalB2 = SampleMath::Vec3FTransformNormal(dominoNormals[1], transformB);
    QCAR::Vec3F normalB3 = SampleMath::Vec3FTransformNormal(dominoNormals[2], transformB);
    
    QCAR::Vec3F edgeAxisA1B1 = SampleMath::Vec3FCross(normalA1, normalB1);
    QCAR::Vec3F edgeAxisA1B2 = SampleMath::Vec3FCross(normalA1, normalB2);
    QCAR::Vec3F edgeAxisA1B3 = SampleMath::Vec3FCross(normalA1, normalB3);
    
    QCAR::Vec3F edgeAxisA2B1 = SampleMath::Vec3FCross(normalA2, normalB1);
    QCAR::Vec3F edgeAxisA2B2 = SampleMath::Vec3FCross(normalA2, normalB2);
    QCAR::Vec3F edgeAxisA2B3 = SampleMath::Vec3FCross(normalA2, normalB3);
    
    QCAR::Vec3F edgeAxisA3B1 = SampleMath::Vec3FCross(normalA3, normalB1);
    QCAR::Vec3F edgeAxisA3B2 = SampleMath::Vec3FCross(normalA3, normalB2);
    QCAR::Vec3F edgeAxisA3B3 = SampleMath::Vec3FCross(normalA3, normalB3);
    
    for (int i = 0; i < 8; i++) {
        dominoTransformedVerticesA[i] = SampleMath::Vec3FTransform(dominoBaseVertices[i], transformA);
        dominoTransformedVerticesB[i] = SampleMath::Vec3FTransform(dominoBaseVertices[i], transformB);
    }
    
    if (isSeparatingAxis(normalA1)) return false;
    if (isSeparatingAxis(normalA2)) return false;
    if (isSeparatingAxis(normalA3)) return false;
    if (isSeparatingAxis(normalB1)) return false;
    if (isSeparatingAxis(normalB2)) return false;
    if (isSeparatingAxis(normalB3)) return false;
    if (isSeparatingAxis(edgeAxisA1B1)) return false;
    if (isSeparatingAxis(edgeAxisA1B2)) return false;
    if (isSeparatingAxis(edgeAxisA1B3)) return false;
    if (isSeparatingAxis(edgeAxisA2B1)) return false;
    if (isSeparatingAxis(edgeAxisA2B2)) return false;
    if (isSeparatingAxis(edgeAxisA2B3)) return false;
    if (isSeparatingAxis(edgeAxisA3B1)) return false;
    if (isSeparatingAxis(edgeAxisA3B2)) return false;
    if (isSeparatingAxis(edgeAxisA3B3)) return false;
    
    return true;
}


bool
isSeparatingAxis(QCAR::Vec3F axis)
{
    // Determine whether or not the given axis separates
    // the globally stored transformed vertices of the two bounding boxes
    
    float magnitude = axis.data[0] * axis.data[0] + axis.data[1] * axis.data[1] + axis.data[2] * axis.data[2];
    if (magnitude < 0.00001) return false;
    
    float minA, maxA, minB, maxB;
    
    minA = maxA = SampleMath::Vec3FDot(dominoTransformedVerticesA[0], axis);
    minB = maxB = SampleMath::Vec3FDot(dominoTransformedVerticesB[0], axis);
    
    float p;
    
    for (int i = 1; i < 8; i++) {
        p = SampleMath::Vec3FDot(dominoTransformedVerticesA[i], axis);
        if (p < minA) minA = p;
        if (p > maxA) maxA = p;
        
        p = SampleMath::Vec3FDot(dominoTransformedVerticesB[i], axis);
        if (p < minB) minB = p;
        if (p > maxB) maxB = p;
    }
    
    if (maxA < minB) return true;
    if (minA > maxB) return true;
    
    return false;
}



// ----------------------------------------------------------------------------
// Picking
// ----------------------------------------------------------------------------

bool
checkIntersectionLine(QCAR::Matrix44F transformA, QCAR::Vec3F pointA, QCAR::Vec3F pointB)
{
    // Use the separating axis theorem to determine whether or not
    // the line intersects the object-oriented bounding box
    
    transformA = SampleMath::Matrix44FTranspose(transformA);
    QCAR::Vec3F lineDir = SampleMath::Vec3FSub(pointB, pointA);
    
    QCAR::Vec3F normalA1 = SampleMath::Vec3FTransformNormal(dominoNormals[0], transformA);
    QCAR::Vec3F normalA2 = SampleMath::Vec3FTransformNormal(dominoNormals[1], transformA);
    QCAR::Vec3F normalA3 = SampleMath::Vec3FTransformNormal(dominoNormals[2], transformA);
    
    QCAR::Vec3F crossA1 = SampleMath::Vec3FCross(normalA1, lineDir);
    QCAR::Vec3F crossA2 = SampleMath::Vec3FCross(normalA2, lineDir);
    QCAR::Vec3F crossA3 = SampleMath::Vec3FCross(normalA3, lineDir);
    
    for (int i = 0; i < 8; i++) {
        dominoTransformedVerticesA[i] = SampleMath::Vec3FTransform(dominoBaseVertices[i], transformA);
    }
    
    if (isSeparatingAxisLine(normalA1, pointA, pointB)) return false;
    if (isSeparatingAxisLine(normalA2, pointA, pointB)) return false;
    if (isSeparatingAxisLine(normalA3, pointA, pointB)) return false;
    
    if (isSeparatingAxisLine(crossA1, pointA, pointB)) return false;
    if (isSeparatingAxisLine(crossA2, pointA, pointB)) return false;
    if (isSeparatingAxisLine(crossA3, pointA, pointB)) return false;
    
    return true;
}


bool
isSeparatingAxisLine(QCAR::Vec3F axis, QCAR::Vec3F pointA, QCAR::Vec3F pointB)
{
    // Determine whether or not the given axis separates
    // the globally stored transformed vertices of the bounding box
    // and the given line
    
    float magnitude = axis.data[0] * axis.data[0] + axis.data[1] * axis.data[1] + axis.data[2] * axis.data[2];
    if (magnitude < 0.00001) return false;
    
    float minA, maxA, minB, maxB;
    
    minA = maxA = SampleMath::Vec3FDot(dominoTransformedVerticesA[0], axis);
    
    float p;
    
    for (int i = 1; i < 8; i++) {
        p = SampleMath::Vec3FDot(dominoTransformedVerticesA[i], axis);
        if (p < minA) minA = p;
        if (p > maxA) maxA = p;
    }
    
    minB = maxB = SampleMath::Vec3FDot(pointA, axis);
    p = SampleMath::Vec3FDot(pointB, axis);
    if (p < minB) minB = p;
    if (p > maxB) maxB = p;
    
    if (maxA < minB) return true;
    if (minA > maxB) return true;
    
    return false;
}



// ----------------------------------------------------------------------------
// Time utility
// ----------------------------------------------------------------------------

unsigned long
getCurrentTimeMS() {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    unsigned long s = tv.tv_sec * 1000;
    unsigned long us = tv.tv_usec / 1000;
    return s + us;
}
