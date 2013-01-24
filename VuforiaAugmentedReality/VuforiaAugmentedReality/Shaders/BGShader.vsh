/*==============================================================================
            Copyright (c) 2012 QUALCOMM Austria Research Center GmbH.
            All Rights Reserved.
            Qualcomm Confidential and Proprietary
==============================================================================*/


#define STRINGIFY(x) #x

static const char vertexShaderSrc[] = STRINGIFY(
    attribute vec4 vertexPosition;
    attribute vec2 vertexTexCoord;
    uniform mat4 projectionMatrix;
    uniform float touchLocation_x;
    uniform float touchLocation_y;

    varying vec2 texCoord;
    
    vec4 tmpVertex;

    void main()
    {
        tmpVertex=vertexPosition;
        
        vec2 directionVector=tmpVertex.xy-vec2(touchLocation_x, touchLocation_y);
        float distance = length(directionVector);
        float sinDistance = (sin(distance)+1.0);
        float strength = 0.3;
        directionVector=normalize(directionVector);
        
        if (sinDistance>0.0) 
        {
            if (touchLocation_x>-1.0)
            {
                tmpVertex.xy+=(directionVector*(strength/sinDistance));
            }
        }
        
        gl_Position = projectionMatrix * tmpVertex;
        texCoord = vertexTexCoord;
    }
);
