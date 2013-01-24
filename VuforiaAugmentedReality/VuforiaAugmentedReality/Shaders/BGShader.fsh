/*==============================================================================
            Copyright (c) 2012 QUALCOMM Austria Research Center GmbH.
            All Rights Reserved.
            Qualcomm Confidential and Proprietary
==============================================================================*/


#define STRINGIFY(x) #x

static const char fragmentShaderSrc[] = STRINGIFY(
    precision mediump float;
    varying vec2 texCoord;
    uniform sampler2D texSampler2D;
    void main ()
    {
        vec3 incoming = texture2D(texSampler2D, texCoord).rgb;
        float colorOut=(incoming.r+incoming.g+incoming.b);
        gl_FragColor.rgb = incoming;
//        gl_FragColor.rgba = vec4(colorOut, colorOut, colorOut, 1.0);
    }
);
