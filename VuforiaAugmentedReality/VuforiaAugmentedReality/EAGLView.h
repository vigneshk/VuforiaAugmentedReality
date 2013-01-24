/*==============================================================================
            Copyright (c) 2012 QUALCOMM Austria Research Center GmbH.
            All Rights Reserved.
            Qualcomm Confidential and Proprietary
==============================================================================*/

#import "AR_EAGLView.h"

// This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView
// subclass.  The view content is basically an EAGL surface you render your
// OpenGL scene into.  Note that setting the view non-opaque will only work if
// the EAGL surface has an alpha channel.
@interface EAGLView : AR_EAGLView
{
@private
    // Coordinates of user touch
    float touchLocation_X;
    float touchLocation_Y;
    bool geoViewActive;
    bool appInitializedForDefault;
    bool appInitializedForDomino;
    // ----- Video background OpenGL data -----
    struct tagVideoBackgroundShader {
        // These handles are required to pass the values to the video background
        // shaders
        GLuint vbShaderProgramID;
        GLuint vbVertexPositionHandle;
        GLuint vbVertexTexCoordHandle;
        GLuint vbTexSampler2DHandle;
        GLuint vbProjectionMatrixHandle;
        GLuint vbTouchLocationXHandle;
        GLuint vbTouchLocationYHandle;
        
        // This flag indicates whether the mesh values have been initialized
        bool vbMeshInitialized;
    } videoBackgroundShader;
}

@property (readwrite) float touchLocation_X;
@property (readwrite) float touchLocation_Y;
@property (readwrite) bool geoViewActive;
@end
