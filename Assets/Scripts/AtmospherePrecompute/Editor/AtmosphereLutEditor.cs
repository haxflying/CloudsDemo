using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(AtmosphereLut))]
public class AtmosphereLutEditor : Editor {

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        AtmosphereLut generator = target as AtmosphereLut;

        if(GUILayout.Button("Bake"))
        {
            generator.Bake();
        }
    }
}
