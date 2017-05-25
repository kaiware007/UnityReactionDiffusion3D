// SceneCameraControl.cs Made by XJINE : https://github.com/XJINE/Unity3D_SceneCameraControl

using UnityEngine;

public class SceneCameraControl : MonoBehaviour
{
    private Vector3 moveTarget = Vector3.zero;
    private Vector3 rotateTarget = new Vector3(0, 0, 1);

    public enum MouseButton
    {
        Left = 0,
        Right = 1,
        Middle = 2
    }

    public enum MouseMove
    {
        X = 0,
        Y = 1,
        ScrollWheel = 2
    }

    private static readonly string[] MouseMoveString = new string[]
    {
        "Mouse X",
        "Mouse Y",
        "Mouse ScrollWheel"
    };

    public bool resetCameraSettings = false;
    public Vector3 resetCameraPosition = Vector3.zero;
    public Vector3 resetCameraRotation = Vector3.zero;

    public MouseMove moveTrigger = MouseMove.ScrollWheel;
    public bool enableMove = true;
    public bool invertMoveDirection = false;
    public float moveSpeed = 6f;
    public bool limitMoveX = false;
    public bool limitMoveY = false;
    public bool limitMoveZ = false;
    public bool smoothMove = true;
    public float smoothMoveSpeed = 10f;

    public MouseButton rotateTrigger = MouseButton.Right;
    public bool enableRotate = true;
    public bool invertRotateDirection = false;
    public float rotateSpeed = 3f;
    public bool limitRotateX = false;
    public bool limitRotateY = false;
    public bool smoothRotate = true;
    public float smoothRotateSpeed = 10f;

    public MouseButton dragTrigger = MouseButton.Middle;
    public bool enableDrag = true;
    public bool invertDragDirection = false;
    public float dragSpeed = 3f;
    public bool limitDragX = false;
    public bool limitDragY = false;
    public bool smoothDrag = true;
    public float smoothDragSpeed = 10f;

    void Start()
    {
        this.moveTarget = this.transform.position;
        this.rotateTarget = this.transform.forward;
    }

    void Update()
    {
        Move();
        Rotate();
        Drag();
        Reset();
    }

    // 入力が有効なときだけ target を更新します。
    // 入力が有効でないとき、すべての処理をスキップすると、
    // Lerp, Slerp によるスムーズな移動・回転が実行されなくなります。

    private void Move()
    {
        if (!this.enableMove)
        {
            return;
        }

        float moveAmount = Input.GetAxis(SceneCameraControl.MouseMoveString[(int)this.moveTrigger]);

        if (moveAmount != 0)
        {
            float direction = this.invertMoveDirection ? -1 : 1;
            this.moveTarget = this.transform.forward;
            this.moveTarget *= this.moveSpeed * moveAmount * direction;
            this.moveTarget += this.transform.position;

            if (this.limitMoveX)
            {
                this.moveTarget.x = this.transform.position.x;
            }

            if (this.limitMoveY)
            {
                this.moveTarget.y = this.transform.position.y;
            }

            if (this.limitMoveZ)
            {
                this.moveTarget.z = this.transform.position.z;
            }
        }

        if (this.smoothMove)
        {
            if (this.moveTarget == this.transform.position)
            {
                this.moveTarget = this.transform.position;
            }

            this.transform.position =
                Vector3.Lerp(this.transform.position,
                             this.moveTarget,
                             Time.deltaTime * this.smoothMoveSpeed);
        }
        else
        {
            this.transform.position = moveTarget;
        }
    }

    private void Rotate()
    {
        if (!this.enableRotate)
        {
            return;
        }

        float direction = this.invertRotateDirection ? -1 : 1;
        float mouseX = Input.GetAxis(SceneCameraControl.MouseMoveString[(int)MouseMove.X]) * direction;
        float mouseY = Input.GetAxis(SceneCameraControl.MouseMoveString[(int)MouseMove.Y]) * direction;

        if (Input.GetMouseButton((int)this.rotateTrigger))
        {
            if (!this.limitRotateX)
            {
                this.rotateTarget = Quaternion.Euler(0, mouseX * this.rotateSpeed, 0) * this.rotateTarget;
            }

            if (!this.limitRotateY)
            {
                this.rotateTarget =
                    Quaternion.AngleAxis(mouseY * this.rotateSpeed,
                                         Vector3.Cross(this.transform.forward, Vector3.up)) * this.rotateTarget;
            }
        }

        if (this.smoothRotate)
        {
            this.transform.rotation =
                Quaternion.Slerp(this.transform.rotation,
                                 Quaternion.LookRotation(this.rotateTarget),
                                 Time.deltaTime * this.smoothRotateSpeed);
        }
        else
        {
            this.transform.rotation = Quaternion.LookRotation(this.rotateTarget);
        }
    }

    private void Drag()
    {
        if (!this.enableDrag)
        {
            return;
        }

        // direction の方向が Move, Rotate と逆方向な点に注意する。

        float direction = this.invertDragDirection ? 1 : -1;
        float mouseX = Input.GetAxis(SceneCameraControl.MouseMoveString[(int)MouseMove.X]) * direction;
        float mouseY = Input.GetAxis(SceneCameraControl.MouseMoveString[(int)MouseMove.Y]) * direction;

        if (Input.GetMouseButton((int)this.dragTrigger))
        {
            this.moveTarget = this.transform.position;

            if (!this.limitDragX)
            {
                this.moveTarget += this.transform.right * mouseX * dragSpeed;
            }

            if (!this.limitDragY)
            {
                this.moveTarget += Vector3.up * mouseY * dragSpeed;
            }
        }

        if (this.smoothDrag)
        {
            this.transform.position =
                Vector3.Lerp(this.transform.position,
                             this.moveTarget,
                             Time.deltaTime * this.smoothDragSpeed);
        }
        else
        {
            this.transform.position = this.moveTarget;
        }
    }

    private void Reset()
    {
        if (!this.resetCameraSettings)
        {
            return;
        }

        this.transform.position = this.resetCameraPosition;
        this.transform.rotation = Quaternion.Euler(this.resetCameraRotation);
        this.moveTarget = this.transform.position;
        this.rotateTarget = this.transform.forward;

        this.resetCameraSettings = false;
    }
}