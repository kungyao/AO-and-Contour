using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

//[ExecuteInEditMode]
public class Contour : MonoBehaviour
{
    public Camera _myCamera;
    public GameObject _renderObject;

    public RenderTexture renTexture;

    public Renderer cornerRenderer;
    [Range(0, 31)]
    public int layer = 31;
    public int renderWidth = 512;

    bool flag = false;
    void Update()
    {
        //if (_myCamera)
        //{
        //    Material mat = transform.GetComponent<Renderer>().sharedMaterial;
        //    mat.SetVector("_MyCameraPosition", _myCamera.transform.position);
        //}

        if (Input.GetKeyDown(KeyCode.A))
            flag = true;
        else if(Input.GetKeyDown(KeyCode.B))
            flag = false;

        if (flag)
        {
            AddBuffer();
        }
        else
        {
            _myCamera.RemoveAllCommandBuffers();
        }
    }

    void AddBuffer()
    {
        _myCamera.RemoveAllCommandBuffers();

        //Shader cornerSahder = Shader.Find("MyShader/valley");
        //Material cornerMaterial = new Material(cornerSahder);
        //cornerMaterial.hideFlags = HideFlags.HideAndDontSave;

        cornerRenderer.material.SetVector("_MyCameraPosition", _myCamera.transform.position);

        CommandBuffer commandBuffer = new CommandBuffer();

        int valleyID = Shader.PropertyToID("_ValleyTexture");

        commandBuffer.GetTemporaryRT(valleyID, renderWidth, renderWidth, 0, FilterMode.Point, RenderTextureFormat.RFloat);
        commandBuffer.SetRenderTarget(valleyID);
        commandBuffer.ClearRenderTarget(true, true, Color.white, 1f);
        commandBuffer.DrawRenderer(cornerRenderer, cornerRenderer.material, 0, 0);
        commandBuffer.SetGlobalTexture("_ValleyTexture", valleyID);

        commandBuffer.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
        commandBuffer.DrawRenderer(cornerRenderer, cornerRenderer.material, 0, 1);

        //commandBuffer.SetRenderTarget(BuiltinRenderTextureType.CameraTarget);
        //commandBuffer.DrawRenderer(cornerRenderer, cornerRenderer.material, 0, 0);

        commandBuffer.ReleaseTemporaryRT(valleyID);

        _myCamera.AddCommandBuffer(CameraEvent.AfterForwardAlpha, commandBuffer);
    }

    void RenderValley()
    {
        int oriLayer = _renderObject.layer;
        // change render object to render layer
        _renderObject.layer = layer;
        // create temporary camera
        GameObject tmpCamObject = new GameObject("Temp Cam Object");
        tmpCamObject.transform.position = transform.position;
        Camera tmpCam = tmpCamObject.AddComponent<Camera>();
        //tmpCam.targetTexture = RenderTexture.GetTemporary(renderWidth, renderWidth, 16);
        tmpCam.targetTexture = renTexture;
        tmpCam.cullingMask = layer;
        tmpCam.RenderWithShader(Shader.Find("MyShader/valley"), "Opaque");
        tmpCam.Render();

        DestroyImmediate(tmpCamObject);
        // to origin layer
        _renderObject.layer = oriLayer;
    }
}
