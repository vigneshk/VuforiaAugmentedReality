/*==============================================================================
            Copyright (c) 2012 QUALCOMM Austria Research Center GmbH.
            All Rights Reserved.
            Qualcomm Confidential and Proprietary
==============================================================================*/

// Subclassed from AR_EAGLView
#import "EAGLView.h"

#import <QCAR/VirtualButton.h>
#import <QCAR/UpdateCallback.h>
#import <QCAR/Renderer.h>
#import <QCAR/VideoBackgroundTextureInfo.h>

#import "QCARutils.h"
#import <QCAR/MultiTarget.h>

#import "Dominoes.h"
#import "Cube.h"
#import "banana.h"
#import "BowlAndSpoonModel.h"
#import "Teapot.h"
#import "Texture.h"
#import "Free_Sofa_04.h"
//#import "head.h"

#ifndef USE_OPENGL1
#import "ShaderUtils.h"
#import "Shaders/BGShader.fsh"
#import "Shaders/BGShader.vsh"
#endif

namespace {
    // Teapot texture filenames
    const char* textureFilenames[] = {
        "banana.jpg", // banana
        "green_glow.png", // cube
        "TextureTeapotRed.png", // teapot
        "TextureTeapotRed.png", // Pretty house/sofa
        "letter_A.png", // used for multi-target flakes demo
        "demon.png" // used for multi-target flakes demo
//        "head.jpg" // head
    };

    class VirtualButton_UpdateCallback : public QCAR::UpdateCallback {
        virtual void QCAR_onUpdate(QCAR::State& state);
    } qcarUpdate;
    
    // Model scale factor
    float kObjectScale; //changed from 3.0
    
    // These values indicate how many rows and columns we want for our video background texture polygon
    const int vbNumVertexCols = 10;
    const int vbNumVertexRows = 10;
    
    // These are the variables for the vertices, coords and inidices
    const int vbNumVertexValues=vbNumVertexCols*vbNumVertexRows*3;      // Each vertex has three values: X, Y, Z
    const int vbNumTexCoord=vbNumVertexCols*vbNumVertexRows*2;          // Each texture coordinate has 2 values: U and V
    const int vbNumIndices=(vbNumVertexCols-1)*(vbNumVertexRows-1)*6;   // Each square is composed of 2 triangles which in turn 
    // have 3 vertices each, so we need 6 indices
    
    // These are the data containers for the vertices, texcoords and indices in the CPU
    float   vbOrthoQuadVertices     [vbNumVertexValues]; 
    float   vbOrthoQuadTexCoords    [vbNumTexCoord]; 
    GLbyte  vbOrthoQuadIndices      [vbNumIndices]; 
    
    // This will hold the data for the projection matrix passed to the vertex shader
    float   vbOrthoProjMatrix[16];
    
    // Multi-targets
    // Constants:
    const float kCubeScaleX = 120.0f * 0.75f / 2.0f;
    const float kCubeScaleY = 120.0f * 1.00f / 2.0f;
    const float kCubeScaleZ = 120.0f * 0.50f / 2.0f;
    
    const float kBowlScaleX = 120.0f * 0.15f;
    const float kBowlScaleY = 120.0f * 0.15f;
    const float kBowlScaleZ = 120.0f * 0.15f;
    
    void initMIT();
    void animateBowl(QCAR::Matrix44F& modelViewMatrix);
    
    
    QCAR::MultiTarget* mit = NULL;
}

@interface EAGLView()
-(QCAR::State)initializeRenderQCAR;
-(void)locateAndDrawObjectTexture:(int)tIdx forObject:(int)i state:(QCAR::State)state;
-(void) finishRenderQCAR;
@end

@interface EAGLView(PrivateMethods)
- (void)CreateVideoBackgroundMesh;
- (void)handleUserTouchEventAtXCoord:(float)x YCoord:(float)y;
- (void)renderFrameQCARForMultiTargets;
@end

@implementation EAGLView

@synthesize touchLocation_X, touchLocation_Y;
@synthesize geoViewActive;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
	if (self)
    {
        // create list of textures we want loading - ARViewController will do this for us
        int nTextures = sizeof(textureFilenames) / sizeof(textureFilenames[0]);
        for (int i = 0; i < nTextures; ++i)
        {
            [textureList addObject: [NSString stringWithUTF8String:textureFilenames[i]]];
        }
        
        touchLocation_X = -100.0;
        touchLocation_Y = -100.0;
        
        self.userInteractionEnabled = NO;
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////
// Initialise the application
- (void)initApplication
{
    if ([[QCARutils getInstance] arMode] == AR_MODE_DOMINO && !appInitializedForDomino)
    {
        appInitializedForDomino =true;
        appInitializedForDefault =false;
        initializeDominoes();
        [self setup3dObjects];
    }
    else if ([[QCARutils getInstance] arMode] == AR_MODE_DEFAULT && !appInitializedForDefault)
    {
        appInitializedForDomino =false;
        appInitializedForDefault =true;
        [self setup3dObjects];
    }
}

- (void) setup3dObjects
{
    if ([[QCARutils getInstance] arMode] == AR_MODE_DOMINO)
    {
        dominoesSetTextures(textures);        
        return;
    }
    else if ([[QCARutils getInstance] arMode] == AR_MODE_FLAKES)
    {
        return;
    }
    
    [objects3D removeAllObjects];
    // build the array of objects we want drawn and their texture
    // in this example we have 2 targets and 2 textures, requiring 2 models
    // but using the same underlying 3D model of a teapot
    

    for (int i=0; i < [textures count]; i++)
    {
        Object3D *obj3D = [[Object3D alloc] init];

        switch (i) {
            case 0:
                obj3D.numVertices = 4032;//NUM_TEAPOT_OBJECT_VERTEX;
                obj3D.vertices = bananaVerts;//teapotVertices;
                obj3D.normals = bananaNormals;//teapotNormals;
                obj3D.texCoords = bananaTexCoords;//teapotTexCoords;
                
                obj3D.numIndices = 4032;//NUM_TEAPOT_OBJECT_INDEX;
                obj3D.modelName =@"Banana";
                break;

            case 1:
                obj3D.numVertices = NUM_CUBE_VERTEX;//NUM_TEAPOT_OBJECT_VERTEX;
                obj3D.vertices = cubeVertices;//teapotVertices;
                obj3D.normals = cubeNormals;//teapotNormals;
                obj3D.texCoords = cubeTexCoords;//teapotTexCoords;
                
                obj3D.numIndices = NUM_CUBE_INDEX;//NUM_TEAPOT_OBJECT_INDEX;
                obj3D.modelName =@"Cube";
                break;
                
            case 3:
                obj3D.numVertices = 17584;//NUM_TEAPOT_OBJECT_VERTEX;
                obj3D.vertices = Free_Sofa_04Verts;//teapotVertices;
                obj3D.normals = Free_Sofa_04Normals;//teapotNormals;
                obj3D.texCoords = Free_Sofa_04TexCoords;//teapotTexCoords;
                
//                obj3D.numIndices = 5363;//NUM_TEAPOT_OBJECT_INDEX;
                obj3D.modelName =@"Sofa";
                break;
                
//            case 6:
//                obj3D.numVertices = 344426;//NUM_TEAPOT_OBJECT_VERTEX;
//                obj3D.vertices = headVerts;//teapotVertices;
//                
//                obj3D.modelName =@"Head";
//                break;
                
            case 4:
                obj3D.numVertices = NUM_OBJECT_VERTEX;//NUM_TEAPOT_OBJECT_VERTEX;
                obj3D.vertices = objectVertices;//teapotVertices;
                
                obj3D.normals = objectNormals;
                obj3D.texCoords = objectTexCoords;
                
                obj3D.numIndices = NUM_OBJECT_INDEX;
                obj3D.indices = objectIndices;
                obj3D.modelName =@"Normal Teapot";
                break;

            case 5:
                obj3D.numVertices = NUM_OBJECT_VERTEX;//NUM_TEAPOT_OBJECT_VERTEX;
                obj3D.vertices = objectVertices;//teapotVertices;
                
                obj3D.normals = objectNormals;
                obj3D.texCoords = objectTexCoords;
                
                obj3D.numIndices = NUM_OBJECT_INDEX;
                obj3D.indices = objectIndices;
                obj3D.modelName =@"Designer Teapot";
                break;
                
            default:
                obj3D.numVertices = NUM_TEAPOT_OBJECT_VERTEX;
                obj3D.vertices = teapotVertices;
                obj3D.normals = teapotNormals;
                obj3D.texCoords = teapotTexCoords;
                
                obj3D.numIndices = NUM_TEAPOT_OBJECT_INDEX;
                obj3D.indices = teapotIndices;
                obj3D.modelName =@"Colorful Teapot";
                break;
        }
        
        obj3D.texture = [textures objectAtIndex:i];

        [objects3D addObject:obj3D];
        [[QCARutils getInstance] setModelsList:objects3D];
        [obj3D release];
    }
}


////////////////////////////////////////////////////////////////////////////////
// Do the things that need doing after initialisation
// called after QCAR is initialised but before the camera starts
- (void)postInitQCAR
{
    // These two calls to setHint tell QCAR to split work over multiple
    // frames.  Depending on your requirements you can opt to omit these.
    QCAR::setHint(QCAR::HINT_IMAGE_TARGET_MULTI_FRAME_ENABLED, 1);
    QCAR::setHint(QCAR::HINT_IMAGE_TARGET_MILLISECONDS_PER_MULTI_FRAME, 25);
    
    // Here we could also make a QCAR::setHint call to set the maximum
    // number of simultaneous targets
    // QCAR::setHint(QCAR::HINT_MAX_SIMULTANEOUS_IMAGE_TARGETS, 2);
    
    // register for our call back after tracker processing is done
    QCAR::registerCallback(&qcarUpdate);
}

-(QCAR::State )initializeRenderQCAR
{
    [self setFramebuffer];
    
    // Clear color and depth buffer
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Get the state from QCAR and mark the beginning of a rendering section
    QCAR::State state = QCAR::Renderer::getInstance().begin();
    
    ////////////////////////////////////////////////////////////////////////////
    // This section renders the video background with a
    // custom shader defined in Shaders.h
    QCAR::Renderer::getInstance().bindVideoBackground(0);
    
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    
    // Load the shader and upload the vertex/texcoord/index data
    glViewport(qUtils->viewport.posX, qUtils->viewport.posY, qUtils->viewport.sizeX, qUtils->viewport.sizeY);
    
    // We need a finer mesh for this background
    // We have to create it here because it will request the texture info of the video background
    if (!videoBackgroundShader.vbMeshInitialized)
    {
        [self CreateVideoBackgroundMesh];
    }
    
    glUseProgram(videoBackgroundShader.vbShaderProgramID);
    glVertexAttribPointer(videoBackgroundShader.vbVertexPositionHandle, 3, GL_FLOAT, GL_FALSE, 0, vbOrthoQuadVertices);
    glVertexAttribPointer(videoBackgroundShader.vbVertexTexCoordHandle, 2, GL_FLOAT, GL_FALSE, 0, vbOrthoQuadTexCoords);
    glUniform1i(videoBackgroundShader.vbTexSampler2DHandle, 0);
    glUniformMatrix4fv(videoBackgroundShader.vbProjectionMatrixHandle, 1, GL_FALSE, &vbOrthoProjMatrix[0]);
    glUniform1f(videoBackgroundShader.vbTouchLocationXHandle, ([self touchLocation_X]*2.0)-1.0);
    glUniform1f(videoBackgroundShader.vbTouchLocationYHandle, (2.0-([self touchLocation_Y]*2.0))-1.0);
    
    // Render the video background with the custom shader
    glEnableVertexAttribArray(videoBackgroundShader.vbVertexPositionHandle);
    glEnableVertexAttribArray(videoBackgroundShader.vbVertexTexCoordHandle);
    // TODO: it might be more efficient to use Vertex Buffer Objects here
    glDrawElements(GL_TRIANGLES, vbNumIndices, GL_UNSIGNED_BYTE, vbOrthoQuadIndices);
    glDisableVertexAttribArray(videoBackgroundShader.vbVertexPositionHandle);
    glDisableVertexAttribArray(videoBackgroundShader.vbVertexTexCoordHandle);
    
    // Wrap up this rendering
    glUseProgram(0);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    ShaderUtils::checkGlError("Rendering of the background failed");
    
    ////////////////////////////////////////////////////////////////////////////
    // The following section is similar to image targets
    // we still render the teapot on top of the targets
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);

    return state;
}


// modify renderFrameQCAR here if you want a different 3D rendering model
////////////////////////////////////////////////////////////////////////////////
// Draw the current frame using OpenGL
//
// This method is called by QCAR when it wishes to render the current frame to
// the screen.
//
// *** QCAR will call this method on a single background thread ***
- (void)renderFrameQCAR
{
    if ([[QCARutils getInstance] arMode] == AR_MODE_DOMINO)
    {
        [self initApplication];
        if (APPSTATUS_CAMERA_RUNNING == qUtils.appStatus) {
            [self setFramebuffer];
            renderDominoes();
            [self presentFramebuffer];
        }
        return;
    }
    else if ([[QCARutils getInstance] arMode] == AR_MODE_FLAKES)
    {
        [self renderFrameQCARForMultiTargets];
        return;
    }
    
    QCAR::State state = [self initializeRenderQCAR];
    
    if (self.geoViewActive)
    {
        [self locateAndDrawObjectTexture:0 forObject:0 state:state];
    }
    else
    {
        // Did we find any trackables this frame?
        for (int tIdx = 0; tIdx < state.getNumActiveTrackables(); tIdx++)
        {
            for (int i=0; i < [objects3D count]; i++)
            {
                [self locateAndDrawObjectTexture:tIdx forObject:i state:state];
            }
            
        }
    }
    [self finishRenderQCAR];
}

-(void) finishRenderQCAR
{
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    
    ////////////////////////////////////////////////////////////////////////////
    // It is always important to tell the QCAR Renderer that we are finished
    QCAR::Renderer::getInstance().end();
    
    [self presentFramebuffer];

}

-(void)locateAndDrawObjectTexture:(int)tIdx forObject:(int)i state:(QCAR::State)state
{
    if (i !=[[QCARutils getInstance] selectedModel])
        return;
    
    // Get the trackable:
    const QCAR::Trackable* trackable = state.getActiveTrackable(tIdx);
    QCAR::Matrix44F modelViewMatrix;
    if (!self.geoViewActive)
    {
        modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(trackable->getPose());
    }
        
    float x;
    float y;
    // We have ony one texture, so use it
    switch (i) {
        case 0:
            kObjectScale =120.0f;
            x=0.0f;
            y=0.0f;
            break;

        case 1:
            kObjectScale =30.0f;
            x=0.0f;
            y=0.0f;
            break;
        
        case 3:
            kObjectScale =180.0f;
            x=0.0f;
            y=0.0f;
            break;
            
        default:
            kObjectScale =3.0f;
            x=-20.0f;
            y=-20.0f;
            break;
    }
    Object3D *obj3D = [objects3D objectAtIndex:i];
    
    QCAR::Matrix44F modelViewProjection;
    
    //        ShaderUtils::rotatePoseMatrix(60.0,10.0f, 10.0f, kObjectScale,
    //                                      &modelViewProjection.data[0]);
    ShaderUtils::translatePoseMatrix(x, y, kObjectScale/3,
                                     &modelViewMatrix.data[0]);
    ShaderUtils::scalePoseMatrix(kObjectScale, kObjectScale, kObjectScale,
                                 &modelViewMatrix.data[0]);
    
    ShaderUtils::multiplyMatrix(&qUtils.projectionMatrix.data[0],
                                &modelViewMatrix.data[0] ,
                                &modelViewProjection.data[0]);
    
    
    glUseProgram(shaderProgramID);
    
    switch (i) {
        case 0:
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &bananaVerts[0]);//teapotVertices[0]);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &bananaNormals[0]);//&teapotNormals[0]);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &bananaTexCoords[0]);//teapotTexCoords[0]);

            break;

        case 1:
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &cubeVertices[0]);//teapotVertices[0]);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &cubeNormals[0]);//&teapotNormals[0]);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &cubeTexCoords[0]);//teapotTexCoords[0]);
            break;
            
        case 3:
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &Free_Sofa_04Verts[0]);//teapotVertices[0]);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &Free_Sofa_04Normals[0]);//&teapotNormals[0]);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &Free_Sofa_04TexCoords[0]);//teapotTexCoords[0]);
            
            break;

//        case 6:
//            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
//                                  (const GLvoid*) &headVerts[0]);//teapotVertices[0]);
////            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
////                                  (const GLvoid*) &headNormals[0]);//&teapotNormals[0]);
////            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
////                                  (const GLvoid*) &headTexCoords[0]);//teapotTexCoords[0]);
//            
//            break;
            
        default:
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &teapotVertices[0]);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &teapotNormals[0]);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &teapotTexCoords[0]);

            break;
    }
    //
    //        glVertexPointer(3, GL_FLOAT, 0, bananaVerts);
    //        glNormalPointer(GL_FLOAT, 0, bananaNormals);
    //        glTexCoordPointer(2, GL_FLOAT, 0, bananaTexCoords);
    
    
    glEnableVertexAttribArray(vertexHandle);
    glEnableVertexAttribArray(normalHandle);
    glEnableVertexAttribArray(textureCoordHandle);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, [obj3D.texture textureID]);
    glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE,
                       (GLfloat*)&modelViewProjection.data[0] );
    
    switch (i) {
        case 0:
            // draw data
            glDrawArrays(GL_TRIANGLES, 0, bananaNumVerts);

            break;

        case 1:
            // draw data
            glDrawElements(GL_TRIANGLES, NUM_CUBE_INDEX,
                           GL_UNSIGNED_SHORT,
                           (const GLvoid*) &cubeIndices[0]);
            
            break;
        
        case 3:
            // draw data
            glDrawArrays(GL_TRIANGLES, 0, Free_Sofa_04NumVerts);
            
            break;
        
        case 6:
            // draw data
            glDrawArrays(GL_TRIANGLES, 0, 344426);
            
            break;
        default:
            glDrawElements(GL_TRIANGLES, NUM_TEAPOT_OBJECT_INDEX,
                           GL_UNSIGNED_SHORT,
                           (const GLvoid*) &teapotIndices[0]);

            break;
    }
        
    glDisableVertexAttribArray(vertexHandle);
    glDisableVertexAttribArray(normalHandle);
    glDisableVertexAttribArray(textureCoordHandle);
    
    ShaderUtils::checkGlError("BackgroundTextureAccess renderFrame");

}


////////////////////////////////////////////////////////////////////////////////
// Callback function called by the tracker when each tracking cycle has finished
void VirtualButton_UpdateCallback::QCAR_onUpdate(QCAR::State& state)
{
    // Process the virtual button
    virtualButtonOnUpdate(state);
}

////////////////////////////////////////////////////////////////////////////////
// This function creates the shader program with the vertex and fragment shaders
// defined in Shader.h. It also gets handles to the position of the variables
// for later usage. It also defines a standard orthographic projection matrix
- (void)initShaders
{
    // OpenGL 2 initialisation...
    
    // Initialise augmentation shader data (our parent class can do this for us)
    [super initShaders];
    if ([[QCARutils getInstance] arMode] == AR_MODE_DOMINO)
    {
        dominoesSetShaderProgramID(shaderProgramID);
        dominoesSetVertexHandle(vertexHandle);
        dominoesSetNormalHandle(normalHandle);
        dominoesSetTextureCoordHandle(textureCoordHandle);
        dominoesSetMvpMatrixHandle(mvpMatrixHandle);
        return;
    }
    // Define clear color
    glClearColor(0.0f, 0.0f, 0.0f, QCAR::requiresAlpha() ? 0.0f : 1.0f);
    
    // Initialise video background shader data
    videoBackgroundShader.vbShaderProgramID = ShaderUtils::createProgramFromBuffer(vertexShaderSrc, fragmentShaderSrc);
    
    if (0 < videoBackgroundShader.vbShaderProgramID) {
        // Retrieve handler for vertex position shader attribute variable
        videoBackgroundShader.vbVertexPositionHandle = glGetAttribLocation(videoBackgroundShader.vbShaderProgramID, "vertexPosition");
        
        // Retrieve handler for texture coordinate shader attribute variable
        videoBackgroundShader.vbVertexTexCoordHandle = glGetAttribLocation(videoBackgroundShader.vbShaderProgramID, "vertexTexCoord");
        
        // Retrieve handler for texture sampler shader uniform variable
        videoBackgroundShader.vbTexSampler2DHandle = glGetUniformLocation(videoBackgroundShader.vbShaderProgramID, "texSampler2D");
        
        // Retrieve handler for projection matrix shader uniform variable
        videoBackgroundShader.vbProjectionMatrixHandle = glGetUniformLocation(videoBackgroundShader.vbShaderProgramID, "projectionMatrix");
        
        // Retrieve handler for projection matrix shader uniform variable
        videoBackgroundShader.vbTouchLocationXHandle = glGetUniformLocation(videoBackgroundShader.vbShaderProgramID, "touchLocation_x");
        
        // Retrieve handler for projection matrix shader uniform variable
        videoBackgroundShader.vbTouchLocationYHandle = glGetUniformLocation(videoBackgroundShader.vbShaderProgramID, "touchLocation_y");
        
        ShaderUtils::checkGlError("Getting the handles to the shader variables");
        
        // Set the orthographic matrix
        ShaderUtils::setOrthoMatrix(-1.0, 1.0, -1.0, 1.0, -1.0, 1.0, vbOrthoProjMatrix);
    }
    else {
        NSLog(@"Could not initialise video background shader");
    }
}


////////////////////////////////////////////////////////////////////////////////
// This function adds the values to the vertex, coord and indices variables.
// Essentially it defines a mesh from -1 to 1 in X and Y with 
// vbNumVertexRows rows and vbNumVertexCols columns. Thus, if we were to assign
// vbNumVertexRows=10 and vbNumVertexCols=10 we would have a mesh composed of 
// 100 little squares (notice, however, that we work with triangles so it is 
// actually not composed of 100 squares but of 200 triangles). The example
// below shows 4 triangles composing 2 squares.
//      D---E---F
//      | \ | \ |
//      A---B---C
- (void)CreateVideoBackgroundMesh
{
    // Get the texture and image dimensions from QCAR
    const QCAR::VideoBackgroundTextureInfo texInfo=QCAR::Renderer::getInstance().getVideoBackgroundTextureInfo();
    
    // If there is no image data yet then return;
    if ((texInfo.mImageSize.data[0]==0)||(texInfo.mImageSize.data[1]==0)) return;
    
    // These calculate a slope for the texture coords
    float uRatio=((float)texInfo.mImageSize.data[0]/(float)texInfo.mTextureSize.data[0]);
    float vRatio=((float)texInfo.mImageSize.data[1]/(float)texInfo.mTextureSize.data[1]);
    float uSlope=uRatio/(vbNumVertexCols-1);
    float vSlope=vRatio/(vbNumVertexRows-1);
    
    // These calculate a slope for the vertex values in this case we have a span of 2, from -1 to 1
    float totalSpan=2.0f;
    float colSlope=totalSpan/(vbNumVertexCols-1);
    float rowSlope=totalSpan/(vbNumVertexRows-1);
    
    // Some helper variables
    int currentIndexPosition=0; 
    int currentVertexPosition=0;
    int currentCoordPosition=0;
    int currentVertexIndex=0;
    
    for (int j=0; j<vbNumVertexRows; j++)
    {
        for (int i=0; i<vbNumVertexCols; i++)
        {
            // We populate the mesh with a regular grid
            vbOrthoQuadVertices[currentVertexPosition   /*X*/] = ((colSlope*i)-(totalSpan/2.0f));   // We subtract this because the values range from -totalSpan/2 to totalSpan/2
            vbOrthoQuadVertices[currentVertexPosition+1 /*Y*/] = ((rowSlope*j)-(totalSpan/2.0f));
            vbOrthoQuadVertices[currentVertexPosition+2 /*Z*/] = 0.0f;                              // It is all a flat polygon orthogonal to the view vector
            
            // We also populate its associated texture coordinate
            vbOrthoQuadTexCoords[currentCoordPosition   /*U*/] = uSlope*i;
            vbOrthoQuadTexCoords[currentCoordPosition+1 /*V*/] = vRatio - (vSlope*j);
            
            // Now we populate the triangles that compose the mesh
            // First triangle is the upper right of the vertex
            if (j<vbNumVertexRows-1)
            {
                if (i<vbNumVertexCols-1) // In the example above this would make triangles ABD and BCE
                {
                    vbOrthoQuadIndices[currentIndexPosition  ]=currentVertexIndex;
                    vbOrthoQuadIndices[currentIndexPosition+1]=currentVertexIndex+1;
                    vbOrthoQuadIndices[currentIndexPosition+2]=currentVertexIndex+vbNumVertexCols;
                    currentIndexPosition+=3;
                }
                if (i>0) // In the example above this would make triangles BED and CFE
                {
                    vbOrthoQuadIndices[currentIndexPosition  ]=currentVertexIndex;
                    vbOrthoQuadIndices[currentIndexPosition+1]=currentVertexIndex+vbNumVertexCols;
                    vbOrthoQuadIndices[currentIndexPosition+2]=currentVertexIndex+vbNumVertexCols-1;
                    currentIndexPosition+=3;
                }
            }
            currentVertexPosition+=3;
            currentCoordPosition+=2;
            currentVertexIndex+=1;
        }
    }
    
    videoBackgroundShader.vbMeshInitialized=true;
}


// The user touched the screen
- (void)touchesBegan:(NSSet*)touches withEvent:(UIEvent*)event
{
    if ([[QCARutils getInstance] arMode] == AR_MODE_DOMINO)
    {
        UITouch* touch = [touches anyObject];
        CGPoint location = [touch locationInView:self];
        dominoesTouchEvent(ACTION_DOWN, 0, location.x, location.y);
        return;
    }
    [self touchesMoved:touches withEvent:event];
}


- (void)touchesMoved:(NSSet*)touches withEvent:(UIEvent*)event
{
    if ([[QCARutils getInstance] arMode] == AR_MODE_DOMINO)
    {
        UITouch* touch = [touches anyObject];
        CGPoint location = [touch locationInView:self];
        dominoesTouchEvent(ACTION_MOVE, 0, location.x, location.y);
        return;
    }
    UITouch* touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    CGRect rect = [self bounds];
    
    [self handleUserTouchEventAtXCoord:(point.x / rect.size.width) YCoord:(point.y / rect.size.height)];
}


- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
    if ([[QCARutils getInstance] arMode] == AR_MODE_DOMINO)
    {
        UITouch* touch = [touches anyObject];
        CGPoint location = [touch locationInView:self];
        dominoesTouchEvent(ACTION_UP, 0, location.x, location.y);
        return;
    }
    [self handleUserTouchEventAtXCoord:-100 YCoord:-100];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([[QCARutils getInstance] arMode] == AR_MODE_DOMINO)
    {
        UITouch* touch = [touches anyObject];
        CGPoint location = [touch locationInView:self];
        dominoesTouchEvent(ACTION_CANCEL, 0, location.x, location.y);
        return;
    }
    // needs implementing even if it does nothing
    [self handleUserTouchEventAtXCoord:-100 YCoord:-100];
}

- (void)handleUserTouchEventAtXCoord:(float)x YCoord:(float)y
{
    // Use touch coordinates for the Loupe effect.  Note: the value -100.0 is
    // simply used as a flag for the shader to ignore the position
    
    // Thread-safe access to touch location data members
    [self setTouchLocation_X:x];
    [self setTouchLocation_Y:y];
}

////////////////////////////////////////////////////////////////////////////////
// Draw the current frame using OpenGL
//
// This method is called by QCAR when it wishes to render the current frame to
// the screen.
//
// *** QCAR will call this method on a background thread ***
- (void)renderFrameQCARForMultiTargets
{
    if (APPSTATUS_CAMERA_RUNNING == qUtils.appStatus) {
        [super setFramebuffer];
        
        //LOG("Java_com_qualcomm_QCARSamples_MultiTargets_GLRenderer_renderFrame");
        ShaderUtils::checkGlError("Check gl errors prior render Frame");
        
        // Clear color and depth buffer
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        // Render video background:
        QCAR::State state = QCAR::Renderer::getInstance().begin();
        QCAR::Renderer::getInstance().drawVideoBackground();
        
        glEnable(GL_DEPTH_TEST);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        
        // Did we find any trackables this frame?
        if (state.getNumActiveTrackables())
        {
            // Get the trackable:
            const QCAR::Trackable* trackable=NULL;
            int numTrackables=state.getNumActiveTrackables();
            
            // Browse trackables searching for the MultiTarget
            for (int j=0;j<numTrackables;j++)
            {
                trackable = state.getActiveTrackable(j);
                if (trackable->getType() == QCAR::Trackable::MULTI_TARGET) break;
                trackable=NULL;
            }
            
            // If it was not found exit
            if (trackable==NULL)
            {
                // Clean up and leave
                glDisable(GL_BLEND);
                glDisable(GL_DEPTH_TEST);
                
                QCAR::Renderer::getInstance().end();
                return;
            }
            
            
            QCAR::Matrix44F modelViewMatrix =
            QCAR::Tool::convertPose2GLMatrix(trackable->getPose());
            QCAR::Matrix44F modelViewProjection;
            ShaderUtils::scalePoseMatrix(kCubeScaleX, kCubeScaleY, kCubeScaleZ,
                                         &modelViewMatrix.data[0]);
            ShaderUtils::multiplyMatrix(&qUtils.projectionMatrix.data[0],
                                        &modelViewMatrix.data[0],
                                        &modelViewProjection.data[0]);
            
            glUseProgram(shaderProgramID);
            
            // Draw the cube:
            
            glEnable(GL_CULL_FACE);
            
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &cubeVertices[0]);
            
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &cubeNormals[0]);
            
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &cubeTexCoords[0]);
            
            glEnableVertexAttribArray(vertexHandle);
            
            glEnableVertexAttribArray(normalHandle);
            
            glEnableVertexAttribArray(textureCoordHandle);
            
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, [[textures objectAtIndex:4] textureID]);
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE,
                               (GLfloat*)&modelViewProjection.data[0] );
            glDrawElements(GL_TRIANGLES, NUM_CUBE_INDEX, GL_UNSIGNED_SHORT,
                           (const GLvoid*) &cubeIndices[0]);
            glDisable(GL_CULL_FACE);
            
            // Draw the bowl:
            modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(trackable->getPose());
            
            // Remove the following line to make the bowl stop spinning:
            animateBowl(modelViewMatrix);
            
            ShaderUtils::translatePoseMatrix(0.0f, -0.50f*120.0f, 1.35f*120.0f,
                                             &modelViewMatrix.data[0]);
            ShaderUtils::rotatePoseMatrix(-90.0f, 1.0f, 0, 0,
                                          &modelViewMatrix.data[0]);
            
            ShaderUtils::scalePoseMatrix(kBowlScaleX, kBowlScaleY, kBowlScaleZ,
                                         &modelViewMatrix.data[0]);
            ShaderUtils::multiplyMatrix(&qUtils.projectionMatrix.data[0],
                                        &modelViewMatrix.data[0],
                                        &modelViewProjection.data[0]);
            
            glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &objectVertices[0]);
            glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &objectNormals[0]);
            glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                                  (const GLvoid*) &objectTexCoords[0]);
            
            glBindTexture(GL_TEXTURE_2D, [[textures objectAtIndex:5] textureID]);
            
            glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE,
                               (GLfloat*)&modelViewProjection.data[0] );
            
            glDrawElements(GL_TRIANGLES, NUM_OBJECT_INDEX, GL_UNSIGNED_SHORT,
                           (const GLvoid*) &objectIndices[0]);
            
            ShaderUtils::checkGlError("MultiTargets renderFrameQCAR");
            
        }
        
        glDisable(GL_BLEND);
        glDisable(GL_DEPTH_TEST);
        
        glDisableVertexAttribArray(vertexHandle);
        glDisableVertexAttribArray(normalHandle);
        glDisableVertexAttribArray(textureCoordHandle);
        
        QCAR::Renderer::getInstance().end();
        [super presentFramebuffer];
    }
}

namespace {
    void
    initMIT()
    {
        //
        // This function checks the current tracking setup for completeness. If
        // it finds that something is missing, then it creates it and configures it:
        // Any MultiTarget and Part elements missing from the config.xml file
        // will be created.
        //
        
        NSLog(@"Beginning to check the tracking setup");
        
        // Configuration data - identical to what is in the config.xml file
        //
        // If you want to recreate the trackable assets using the on-line TMS server
        // using the original images provided in the sample's media folder, use the
        // following trackable sizes on creation to get identical visual results:
        // create a cuboid with width = 90 ; height = 120 ; length = 60.
        
        const char* names[6]   = { "FlakesBox.Front", "FlakesBox.Back", "FlakesBox.Left", "FlakesBox.Right", "FlakesBox.Top", "FlakesBox.Bottom" };
        const float trans[3*6] = { 0.0f,  0.0f,  30.0f,
            0.0f,  0.0f, -30.0f,
            -45.0f, 0.0f,  0.0f,
            45.0f, 0.0f,  0.0f,
            0.0f,  60.0f, 0.0f,
            0.0f, -60.0f, 0.0f };
        const float rots[4*6]  = { 1.0f, 0.0f, 0.0f,   0.0f,
            0.0f, 1.0f, 0.0f, 180.0f,
            0.0f, 1.0f, 0.0f, -90.0f,
            0.0f, 1.0f, 0.0f,  90.0f,
            1.0f, 0.0f, 0.0f, -90.0f,
            1.0f, 0.0f, 0.0f,  90.0f };
        
        mit = [[QCARutils getInstance] findMultiTarget];
        if (mit == NULL)
            return;
        
        // Try to find each ImageTarget. If we find it, this actually means that it
        // is not part of the MultiTarget yet: ImageTargets that are part of a
        // MultiTarget don't show up in the list of Trackables.
        // Each ImageTarget that we found, is then made a part of the
        // MultiTarget and a correct pose (reflecting the pose of the
        // config.xml file) is set).
        //
        int numAdded = 0;
        for(int i=0; i<6; i++)
        {
            if(QCAR::ImageTarget* it = [[QCARutils getInstance] findImageTarget:names[i]])
            {
                NSLog(@"ImageTarget '%s' found -> adding it as to the MultiTarget",
                      names[i]);
                
                int idx = mit->addPart(it);
                QCAR::Vec3F t(trans+i*3),a(rots+i*4);
                QCAR::Matrix34F mat;
                
                QCAR::Tool::setTranslation(mat, t);
                QCAR::Tool::setRotation(mat, a, rots[i*4+3]);
                mit->setPartOffset(idx, mat);
                numAdded++;
            }
        }
        
        NSLog(@"Added %d ImageTarget(s) to the MultiTarget", numAdded);
        
        if(mit->getNumParts()!=6)
        {
            NSLog(@"ERROR: The MultiTarget should have 6 parts, but it reports %d parts",
                  mit->getNumParts());
        }
        
        NSLog(@"Finished checking the tracking setup");
    }
    
    double
    getCurrentTime()
    {
        struct timeval tv;
        gettimeofday(&tv, NULL);
        double t = tv.tv_sec + tv.tv_usec/1000000.0;
        return t;
    }
    
    
    void
    animateBowl(QCAR::Matrix44F& modelViewMatrix)
    {
        static float rotateBowlAngle = 0.0f;
        
        static double prevTime = getCurrentTime();
        double time = getCurrentTime();             // Get real time difference
        float dt = (float)(time-prevTime);          // from frame to frame
        
        rotateBowlAngle += dt * 180.0f/3.1415f;     // Animate angle based on time
        
        ShaderUtils::rotatePoseMatrix(rotateBowlAngle, 0.0f, 1.0f, 0.0f,
                                      &modelViewMatrix.data[0]);
        
        prevTime = time;
    }
}

@end
