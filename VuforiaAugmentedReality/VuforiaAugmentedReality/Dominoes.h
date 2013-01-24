/*============================================================================
Copyright (c) 2012 QUALCOMM Austria Research Center GmbH .
All Rights Reserved.
Qualcomm Confidential and Proprietary
============================================================================*/


#ifndef _DOMINOES_H_
#define _DOMINOES_H_

#import <stdio.h>
#import <string.h>
#import <assert.h>
#import <sys/time.h>
#import <math.h>

#ifdef USE_OPENGL1
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#else
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#endif

#import <QCAR/QCAR.h>
#import <QCAR/UpdateCallback.h>
#import <QCAR/CameraDevice.h>
#import <QCAR/Renderer.h>
#import <QCAR/VideoBackgroundConfig.h>
#import <QCAR/Trackable.h>
#import <QCAR/Tool.h>
#import <QCAR/Tracker.h>
#import <QCAR/CameraCalibration.h>
#import <QCAR/ImageTarget.h>
#import <QCAR/VirtualButton.h>
#import <QCAR/Rectangle.h>

#import "ShaderUtils.h"
#import "SampleMath.h"
#import "Texture.h"
#import "ButtonOverlay.h"


#define MAX_DOMINOES 100
#define DOMINO_TILT_SPEED 300.0f
#define MAX_TAP_TIMER 200
#define MAX_TAP_DISTANCE2 400


enum ActionType {
    ACTION_DOWN,
    ACTION_MOVE,
    ACTION_UP,
    ACTION_CANCEL
};

enum DominoState {
    DOMINO_STANDING,
    DOMINO_FALLING,
    DOMINO_RESTING
};


typedef struct _TouchEvent {
    bool isActive;
    int actionType;
    int pointerId;
    float x;
    float y;
    float lastX;
    float lastY;
    float startX;
    float startY;
    float tapX;
    float tapY;
    unsigned long startTime;
    unsigned long dt;
    float dist2;
    bool didTap;
} TouchEvent;

typedef struct _LLNode {
    int id;
    _LLNode* next;
} LLNode;

typedef struct _Domino {
    int id;
    int state;
    
    LLNode* neighborList;
    
    QCAR::Vec2F position;
    float pivotAngle;
    float tiltAngle;
    QCAR::Matrix44F transform;
    QCAR::Matrix44F pickingTransform;
    
    int tippedBy;
    int restingFrameCount;
} Domino;


/*
class VirtualButton_UpdateCallback : public QCAR::UpdateCallback {
    virtual void QCAR_onUpdate(QCAR::State& state);
} qcarUpdate;
 */


void dominoesSetButtonOverlay(ButtonOverlay* overlay);
void dominoesSetTextures(NSArray* t);
void dominoesSetShaderProgramID(int spid);
void dominoesSetVertexHandle(int vh);
void dominoesSetNormalHandle(int nh);
void dominoesSetTextureCoordHandle(int tch);
void dominoesSetMvpMatrixHandle(int mmh);

void initializeDominoes();
bool dominoesIsSimulating();
bool dominoesHasDominoes();
bool dominoesHasRun();

void renderDominoes();
void dominoesTouchEvent(int actionType, int pointerId, float x, float y);
void dominoesStart();
void dominoesReset();
void dominoesClear();
void dominoesDelete();

void virtualButtonOnUpdate(QCAR::State& state);

void initSoundEffect();
void playSoundEffect();
void showDeleteButton();
void hideDeleteButton();
void displayMessage(const char* message);

void updateAugmentation(const QCAR::Trackable* trackable, float dt);
void handleTouches();
void renderAugmentation(const QCAR::Trackable* trackable);
void renderCube(float* transform);

void addVirtualButton();
void removeVirtualButton();
void moveVirtualButton(Domino* domino);
void enableVirtualButton();
void disableVirtualButton();

void initDominoBaseVertices();
void initDominoNormals();

bool canDropDomino(QCAR::Vec2F position);
void dropDomino(QCAR::Vec2F position);
void updateDominoTransform(Domino* domino);
void updatePickingTransform(Domino* domino);

bool runSimulation(Domino* domino, float dt);
void handleCollision(Domino* domino, Domino* otherDomino, float originalTilt);
void adjustPivot(Domino* domino, Domino* otherDomino);
Domino* getDominoById(int id);

void resetDominoes();
void clearDominoes();
void setSelectedDomino(Domino* domino);
void deleteSelectedDomino();

void projectScreenPointToPlane(QCAR::Vec2F point, QCAR::Vec3F planeCenter, QCAR::Vec3F planeNormal,
                               QCAR::Vec3F &intersection, QCAR::Vec3F &lineStart, QCAR::Vec3F &lineEnd);
bool linePlaneIntersection(QCAR::Vec3F lineStart, QCAR::Vec3F lineEnd, QCAR::Vec3F pointOnPlane,
                           QCAR::Vec3F planeNormal, QCAR::Vec3F &intersection);

bool checkIntersection(QCAR::Matrix44F transformA, QCAR::Matrix44F transformB);
bool isSeparatingAxis(QCAR::Vec3F axis);

bool checkIntersectionLine(QCAR::Matrix44F transformA, QCAR::Vec3F pointA, QCAR::Vec3F pointB);
bool isSeparatingAxisLine(QCAR::Vec3F axis, QCAR::Vec3F pointA, QCAR::Vec3F pointB);

unsigned long getCurrentTimeMS();

#endif // _DOMINOES_H_
