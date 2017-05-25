using System.Runtime.InteropServices;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;

public class GPUMarchingCubesDeferredRender : MonoBehaviour {

    public struct ShaderData
    {
        public int Width;
        public int height;
        public int depth;
        public float renderScale;
        public float sampleScale;
        public float threashold;
        public Vector3 lightPos;
    }

    #region public
    public int width = 32;
    public int height = 32;
    public int depth = 32;
    public float renderScale = 1f;
    [Range(0, 10)]
    public float sampleScale = 0.5f;
    [Range(0, 1)]
    public float threashold = 0.5f;
    public Material mat;

    public Vector3 lightPos = new Vector3(0, 2, 0);

    public CameraEvent commandAt = CameraEvent.AfterGBuffer;
    #endregion

    #region private
    int vertexMax = 0;

    ComputeBuffer shaderDataBuffer;
    ShaderData[] shaderData;
    CommandBuffer commandBuffer;

    // 全てのカメラに対して CommandBUffer を適用するために辞書型
    private Dictionary<Camera, CommandBuffer> m_Cameras = new Dictionary<Camera, CommandBuffer>();

    #endregion

    // 全ての CommandBUffer をクリア
    private void Cleanup()
    {
        foreach (var cam in m_Cameras)
        {
            if (cam.Key)
            {
                cam.Key.RemoveCommandBuffer(CameraEvent.AfterSkybox, cam.Value);
            }
        }
        m_Cameras.Clear();
        //Object.DestroyImmediate(mat);
    }

    public void OnEnable()
    {
        Cleanup();
    }

    public void OnDisable()
    {
        Cleanup();
    }

    void Initialize()
    {
        vertexMax = width * height * depth;

        shaderDataBuffer = new ComputeBuffer(1, Marshal.SizeOf(typeof(ShaderData)));
        shaderData = new ShaderData[1];

        Debug.Log("VertexMax " + vertexMax);

    }

    void UpdateShaderData()
    {
        shaderData[0].Width = width;
        shaderData[0].height = height;
        shaderData[0].depth = depth;
        shaderData[0].renderScale = renderScale;
        shaderData[0].sampleScale = sampleScale;
        shaderData[0].threashold = threashold;
        shaderData[0].lightPos = lightPos;
        shaderDataBuffer.SetData(shaderData);
    }

    void UpdateCommandBuffer()
    {
        mat.SetBuffer("_ShaderData", shaderDataBuffer);
    }

    // Use this for initialization
    void Start() {
        Initialize();
        InitCommandBuffer();
    }

    void Update()
    {
        UpdateCommandBuffer();
    }

    void InitCommandBuffer()
    {
        //mat.SetPass(0);
        //mat.SetInt("_Width", width);
        //mat.SetInt("_Height", height);
        //mat.SetInt("_Depth", depth);
        //mat.SetFloat("_Scale", renderScale);
        //mat.SetFloat("_SampleScale", sampleScale);
        //mat.SetFloat("_Threashold", threashold);
        //mat.SetVector("_LightPos", lightPos);

        commandBuffer = new CommandBuffer();
        commandBuffer.name = "Marching Cubes";

        UpdateShaderData();
        UpdateCommandBuffer();

        commandBuffer.DrawProcedural(Matrix4x4.identity, mat, 0, MeshTopology.Points, vertexMax);
    }

    //private void OnRenderObject()
    //{
    //    mat.SetPass(0);
    //    mat.SetInt("_Width", width);
    //    mat.SetInt("_Height", height);
    //    mat.SetInt("_Depth", depth);
    //    mat.SetFloat("_Scale", renderScale);
    //    mat.SetFloat("_SampleScale", sampleScale);
    //    mat.SetFloat("_Threashold", threashold);
    //    mat.SetVector("_LightPos", lightPos);
    //    Graphics.DrawProcedural(MeshTopology.Points, vertexMax, 0);
    //}

    // OnWillRenderObject() はカメラごとに 1 度ずつ呼び出される
    // ここで Camera.current を全て登録してあげれば全てのカメラに対して処理できる
    public void OnRenderObject()
    {
        // --- ここからは初期化 ---
        if (!Application.isPlaying)
            return;

        // 有効でない場合はクリーン
        if (!gameObject.activeInHierarchy || !enabled) {
            Cleanup();
            return;
        }

        // 現在のカメラを取得
        var cam = Camera.current;
        if (!cam) return;

        if ((cam.cullingMask & (1 << gameObject.layer)) == 0)
            return;

        // 既に CommandBuffer を適用済みなら何もしない
        if (m_Cameras.ContainsKey(cam)) return;

        // マテリアルの初期化
        // m_BlurShader は後述のブラーを適用するシェーダ
        //if (!mat) {
        //    mat = new Material(m_BlurShader);
        //    mat.hideFlags = HideFlags.HideAndDontSave;
        //}

        cam.AddCommandBuffer(commandAt, commandBuffer);
        m_Cameras.Add(cam, commandBuffer);
        
    }

    private void OnDestroy()
    {
        if(shaderDataBuffer != null)
        {
            shaderDataBuffer.Release();
            shaderDataBuffer = null;
        }
    }
}
