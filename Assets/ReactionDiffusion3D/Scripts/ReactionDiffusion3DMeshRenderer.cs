using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ReactionDiffusion3DMeshRenderer : ReactionDiffusion3DRenderer
{
    private List<Renderer> rendererList = new List<Renderer>();

    protected override void Initialize()
    {
        base.Initialize();
        var ren = GetComponentsInChildren<Renderer>();
        if (ren != null)
        {
            foreach (var r in ren)
            {
                rendererList.Add(r);
            }
        }
    }

    protected override void UpdateMaterial()
    {
        for (int i = 0; i < rendererList.Count; i++)
        {
            rendererList[i].material.SetTexture("_MainTex", reactionDiffuse.heightMapTexture);
            //rendererList[i].material.SetColor("_Color0", bottomColor);
            //rendererList[i].material.SetColor("_Color1", topColor);
            //rendererList[i].material.SetColor("_Emit0", bottomEmit);
            //rendererList[i].material.SetColor("_Emit1", topEmit);
            //rendererList[i].material.SetFloat("_EmitInt0", bottomEmitIntensity);
            //rendererList[i].material.SetFloat("_EmitInt1", topEmitIntensity);
        }
    }
}
