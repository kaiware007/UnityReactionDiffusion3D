using UnityEngine;

[RequireComponent(typeof(Camera))]
public class SceneCameraController : MonoBehaviour {

    public Vector3 targetPoint; // 注視点
    public float rotateSpeed = 10;
    public float translateSpeed = 1;
    public float zoomSpeed = 5;
	
	// Update is called once per frame
	void Update () {
        float mouseX = Input.GetAxis("Mouse X");
        float mouseY = Input.GetAxis("Mouse Y");
        float mouseWheelScroll = Input.GetAxis("Mouse ScrollWheel");

        // 平行移動
        if (Input.GetMouseButton(2))
        {
            targetPoint += transform.right * mouseX * translateSpeed;
            targetPoint += transform.up * mouseY * translateSpeed;

            this.transform.Translate(mouseX * translateSpeed, mouseY * translateSpeed, 0);
        }

        // 回転
        if (Input.GetMouseButton(1))
        {
            float dist = Vector3.Distance(this.transform.position, targetPoint);

            this.transform.rotation = Quaternion.AngleAxis(rotateSpeed * -mouseY, transform.right) * transform.rotation;
            this.transform.rotation = Quaternion.AngleAxis(rotateSpeed * mouseX, Vector3.up) * transform.rotation;

            targetPoint = this.transform.position + this.transform.forward * dist;
        }

        // ズーム
        if(mouseWheelScroll != 0)
        {
            this.transform.Translate(Vector3.forward * mouseWheelScroll * zoomSpeed);

            float dist = Vector3.Distance(this.transform.position, targetPoint);
            if(dist <= 1f)
            {
                targetPoint = this.transform.position + this.transform.forward * 1f;
            }
        }

        // 注視点の周りを回る
        if (Input.GetMouseButton(0) && (Input.GetKey(KeyCode.LeftAlt) || Input.GetKey(KeyCode.RightAlt)))
        {
            this.transform.RotateAround(targetPoint, transform.right, -mouseY * rotateSpeed);
            this.transform.RotateAround(targetPoint, Vector3.up, mouseX * rotateSpeed);
        }
	}

    private void OnDrawGizmos()
    {
        Gizmos.color = Color.red;

        Gizmos.DrawWireSphere(targetPoint, 0.1f);
    }
}
