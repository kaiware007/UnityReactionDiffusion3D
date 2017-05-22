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
        march = GetComponent<GPUMarchingCubes>();
    }

    protected override void UpdateMaterial()
    {
        march.mat.SetTexture("_MainTex", reactionDiffuse.heightMapTexture);
    }

    private void OnDrawGizmos()
    {
        if (!Application.isPlaying)
            return;

        Vector3 whd = new Vector3(march.Width, march.height, march.depth);
        Vector3 center = transform.position + whd * march.renderScale * 0.5f;
        Gizmos.DrawWireCube(center, whd);
    }
}
