using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(NoiseGenerator))]
public class NoiseGeneratorEditor : Editor {

    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        NoiseGenerator generator = target as NoiseGenerator;


        if(GUILayout.Button("Bake"))
        {
            generator.Bake();
        }
    }
}
