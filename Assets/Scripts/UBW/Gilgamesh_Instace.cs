using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class Gilgamesh_Instace : MonoBehaviour {

    private new MeshRenderer renderer;
    private MaterialPropertyBlock props;

    private void OnEnable()
    {
        renderer = GetComponentInChildren<MeshRenderer>();
        props = new MaterialPropertyBlock();
        SetProperties();
    }

    void SetProperties()
    {
        if (renderer != null)
        {
            props.SetVector("bornPos", transform.parent.position);
            props.SetVector("bornDir", transform.parent.forward);

            renderer.SetPropertyBlock(props);
        }

    }
}
