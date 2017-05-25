using System.Runtime.InteropServices;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

public class GPUMarchingCubesDrawMesh : MonoBehaviour {
    
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

    public Color DiffuseColor = Color.green;
    public Color SpecularColor = Color.white;
    [Range(0,1)]
    public float metallic = 0;
    [Range(0, 1)]
    public float glossiness = 0.5f;

    #endregion

    #region private
    int vertexMax = 0;
    Mesh[] meshs = null;
    Material[] materials = null;

    ReactionDiffusion3D reactionDiffuse;
    #endregion

    void Initialize()
    {
        reactionDiffuse = GetComponent<ReactionDiffusion3D>();

        vertexMax = Width * height * depth;
        
        Debug.Log("VertexMax " + vertexMax);

        CreateMesh();
    }

    void CreateMesh()
    {
        int vertNum = 65534;
        int meshNum = vertexMax / vertNum;
        Debug.Log("meshNum " + meshNum );

        meshs = new Mesh[meshNum];
        materials = new Material[meshNum];

        Bounds bounds = new Bounds(transform.position, new Vector3(Width, height, depth) * renderScale);

        int id = 0;
        for (int i = 0; i < meshNum; i++)
        {
            Vector3[] vertices = new Vector3[vertNum];
            int[] indices = new int[vertNum];
            for(int j = 0; j < vertNum; j++)
            {
                vertices[j].x = (float)(id % Width);
                vertices[j].y = (float)((id / Width) % height);
                vertices[j].z = (float)((id / (Width * height)) % depth);

                indices[j] = j;
                id++;
            }

            meshs[i] = new Mesh();
            meshs[i].vertices = vertices;
            meshs[i].SetIndices(indices, MeshTopology.Points, 0);
            meshs[i].bounds = bounds;

            materials[i] = new Material(mat);
        }
    }

    void RenderMesh()
    {
        for (int i = 0; i < meshs.Length; i++)
        //int i = 2;
        {
            materials[i].SetPass(0);
            materials[i].SetInt("_Width", Width);
            materials[i].SetInt("_Height", height);
            materials[i].SetInt("_Depth", depth);
            materials[i].SetFloat("_Scale", renderScale);
            materials[i].SetFloat("_SampleScale", sampleScale);
            materials[i].SetFloat("_Threashold", threashold);
            materials[i].SetFloat("_Metallic", metallic);
            materials[i].SetFloat("_Glossiness", glossiness);
            materials[i].SetVector("_LightPos", lightPos);
            materials[i].SetColor("_DiffuseColor", DiffuseColor);
            materials[i].SetColor("_SpecularColor", SpecularColor);

            materials[i].SetTexture("_MainTex", reactionDiffuse.heightMapTexture);
            Graphics.DrawMesh(meshs[i], Matrix4x4.identity, materials[i], 0);
        }
    }

    // Use this for initialization
    void Start () {
        Initialize();
    }

    void Update()
    {
        RenderMesh();
    }

    //private void OnRenderObject()
    //{
    //    mat.SetPass(0);
    //    mat.SetInt("_Width", Width);
    //    mat.SetInt("_Height", height);
    //    mat.SetInt("_Depth", depth);
    //    mat.SetFloat("_Scale", renderScale);
    //    mat.SetFloat("_SampleScale", sampleScale);
    //    mat.SetFloat("_Threashold", threashold);
    //    mat.SetVector("_LightPos", lightPos);
    //    Graphics.DrawProcedural(MeshTopology.Points, vertexMax, 0);
    //    mat.SetPass(1);
    //    Graphics.DrawProcedural(MeshTopology.Points, vertexMax, 0);
    //}
}
