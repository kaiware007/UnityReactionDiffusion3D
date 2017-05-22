using System.Runtime.InteropServices;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class GPUMarchingCubes : MonoBehaviour {
    
    #region public
    public int Width = 32;
    public int height = 32;
    public int depth = 32;
    public float renderScale = 1f;
    [Range(0,10)]
    public float sampleScale = 0.5f;
    [Range(0,1)]
    public float threashold = 0.5f;
    public Material mat;

    public Vector3 lightPos = new Vector3(0,2,0);
    #endregion

    #region private
    int vertexMax = 0;
    #endregion

    void Initialize()
    {
        vertexMax = Width * height * depth;

        Debug.Log("VertexMax " + vertexMax);
        
    }
    
    // Use this for initialization
    void Start () {
        Initialize();
    }

    private void OnRenderObject()
    {
        mat.SetPass(0);
        mat.SetInt("_Width", Width);
        mat.SetInt("_Height", height);
        mat.SetInt("_Depth", depth);
        mat.SetFloat("_Scale", renderScale);
        mat.SetFloat("_SampleScale", sampleScale);
        mat.SetFloat("_Threashold", threashold);
        mat.SetVector("_LightPos", lightPos);
        Graphics.DrawProcedural(MeshTopology.Points, vertexMax, 0);
    }
}
