using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ReactionDiffusion3DMarchingCubes : ReactionDiffusion3DRenderer
{
    protected GPUMarchingCubes march;

    protected override void Initialize()
    {
        base.Initialize();
        march = GetComponentInChildren<GPUMarchingCubes>();
    }

    protected override void UpdateMaterial()
    {
        march.mat.SetTexture("_MainTex", reactionDiffuse.heightMapTexture);
    }

    private void OnDrawGizmos()
    {
        if ((!Application.isPlaying)||(march == null))
            return;

        Vector3 whd = new Vector3(march.Width, march.height, march.depth) * march.renderScale;
        Vector3 center = transform.position;
        Gizmos.DrawWireCube(center, whd);
    }
}
