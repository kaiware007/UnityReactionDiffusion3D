using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Runtime.InteropServices;

public struct RDData
{
    public float a;
    public float b;
}

public class ReactionDiffusion3D : MonoBehaviour {
    const int THREAD_NUM_X = 8;

    public int texWidth = 256;
    public int texHeight = 256;
    public int texDepth = 256;

    public float da = 1;
    public float db = 0.5f;
    [Range(0,0.1f)]
    public float f = 0.055f;
    [Range(0, 0.1f)]
    public float k = 0.062f;
    [Range(0, 32)]
    public int speed = 1;

    public int seedSize = 10;
    public int seedNum = 10;

    public int inputMax = 32;

    public ComputeShader cs;

    public RenderTexture heightMapTexture;

    private int kernelUpdate = -1;
    private int kernelDraw = -1;
    private int kernelAddSeed = -1;

    private ComputeBuffer[] buffers;
    private ComputeBuffer inputBuffer;
    private RDData[] bufData;
    private RDData[] bufData2;
    private Vector3[] inputData;
    private int inputIndex = 0;
    //private List<Renderer> rendererList = new List<Renderer>();
    
    void ResetBuffer()
    {
        for (int x = 0; x < texWidth; x++)
        {
            for (int y = 0; y < texHeight; y++)
            {
                for (int z = 0; z < texDepth; z++)
                {
                    int idx = x + y * texWidth + z * texWidth * texHeight;
                    bufData[idx].a = 1;
                    bufData[idx].b = 0;

                    bufData2[idx].a = 1;
                    bufData2[idx].b = 0;
                }
            }
        }

        buffers[0].SetData(bufData);
        buffers[1].SetData(bufData2);
    }

    void Initialize()
    {
        kernelUpdate = cs.FindKernel("Update");
        kernelDraw = cs.FindKernel("Draw");
        kernelAddSeed = cs.FindKernel("AddSeed");

        heightMapTexture = CreateTexture(texWidth, texHeight, texDepth);

        int whd = texWidth * texHeight * texDepth;
        buffers = new ComputeBuffer[2];
        
        cs.SetInt("_TexWidth", texWidth);
        cs.SetInt("_TexHeight", texHeight);
        cs.SetInt("_TexDepth", texDepth);

        for (int i = 0; i < buffers.Length; i++)
        {
            buffers[i] = new ComputeBuffer(whd, Marshal.SizeOf(typeof(RDData)));
        }

        bufData = new RDData[texWidth * texHeight * texDepth];
        bufData2 = new RDData[texWidth * texHeight * texDepth];

        ResetBuffer();

        inputData = new Vector3[inputMax];
        inputIndex = 0;
        inputBuffer = new ComputeBuffer(inputMax, Marshal.SizeOf(typeof(Vector3)));
    }

    RenderTexture CreateTexture(int width, int height, int depth)
    {
        RenderTexture tex = new RenderTexture(width, height, 0, RenderTextureFormat.RFloat, RenderTextureReadWrite.Linear);
        tex.volumeDepth = depth;
        tex.enableRandomWrite = true;
        tex.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        tex.filterMode = FilterMode.Bilinear;
        tex.wrapMode = TextureWrapMode.Repeat;
        tex.Create();

        return tex;
    }

    void UpdateBuffer()
    {
        cs.SetInt("_TexWidth", texWidth);
        cs.SetInt("_TexHeight", texHeight);
        cs.SetInt("_TexDepth", texDepth);
        cs.SetFloat("_DA", da);
        cs.SetFloat("_DB", db);
        cs.SetFloat("_Feed", f);
        cs.SetFloat("_K", k);
        cs.SetBuffer(kernelUpdate, "_BufferRead", buffers[0]);
        cs.SetBuffer(kernelUpdate, "_BufferWrite", buffers[1]);
        cs.Dispatch(kernelUpdate, Mathf.CeilToInt((float)texWidth / THREAD_NUM_X), Mathf.CeilToInt((float)texHeight / THREAD_NUM_X), Mathf.CeilToInt((float)texDepth/ THREAD_NUM_X));

        SwapBuffer();
    }

    void DrawTexture()
    {
        cs.SetInt("_TexWidth", texWidth);
        cs.SetInt("_TexHeight", texHeight);
        cs.SetInt("_TexDepth", texDepth);
        cs.SetBuffer(kernelDraw, "_BufferRead", buffers[0]);
        cs.SetTexture(kernelDraw, "_HeightMap", heightMapTexture);
        cs.Dispatch(kernelDraw, Mathf.CeilToInt((float)texWidth / THREAD_NUM_X), Mathf.CeilToInt((float)texHeight / THREAD_NUM_X), Mathf.CeilToInt((float)texDepth / THREAD_NUM_X));
    }

    void AddSeedBuffer()
    {
        if(inputIndex > 0)
        {
            inputBuffer.SetData(inputData);
            cs.SetInt("_InputNum", inputIndex);
            cs.SetInt("_TexWidth", texWidth);
            cs.SetInt("_TexHeight", texHeight);
            cs.SetInt("_TexDepth", texDepth);
            cs.SetInt("_SeedSize", seedSize);
            cs.SetBuffer(kernelAddSeed, "_InputBufferRead", inputBuffer);
            cs.SetBuffer(kernelAddSeed, "_BufferWrite", buffers[0]);    // update前なので0
            cs.Dispatch(kernelAddSeed, Mathf.CeilToInt((float)inputIndex / (float)THREAD_NUM_X), 1, 1);
            inputIndex = 0;
        }
    }

    void AddSeed(int x, int y, int z)
    {
        if(inputIndex < inputMax)
        {
            inputData[inputIndex].x = x;
            inputData[inputIndex].y = y;
            inputData[inputIndex].z = z;
            inputIndex++;
        }
    }

    void AddRandomSeed(int num)
    {
        for(int i = 0; i < num; i++)
        {
            AddSeed(Random.Range(0, texWidth), Random.Range(0, texHeight), Random.Range(0, texDepth));
        }
    }

    void SwapBuffer()
    {
        ComputeBuffer temp = buffers[0];
        buffers[0] = buffers[1];
        buffers[1] = temp; 
    }

    // Use this for initialization
    void Start () {
        Initialize();

        // 初期配置
        AddRandomSeed(seedNum);
    }

    // Update is called once per frame
    void Update () {
        // 係数ランダム
        if (Input.GetKeyDown(KeyCode.T))
        {
            f = Random.Range(0.01f, 0.1f);
            k = Random.Range(0.01f, 0.1f);
        }

        // リセット
        if (Input.GetKeyDown(KeyCode.R))
        {
            ResetBuffer();
        }

        // 追加
        if (Input.GetKeyDown(KeyCode.A))
        {
            AddRandomSeed(seedNum);
        }

        AddSeedBuffer();

        for (int i = 0; i < speed; i++)
        {
            UpdateBuffer();
        }

        //UpdateMaterial();

        DrawTexture();
    }

    private void OnDestroy()
    {
        if(buffers != null)
        {
            for(int i = 0; i < buffers.Length; i++)
            {
                buffers[i].Release();
                buffers[i] = null;
            }
        }
        if(inputBuffer != null)
        {
            inputBuffer.Release();
            inputBuffer = null;
        }
    }
}
