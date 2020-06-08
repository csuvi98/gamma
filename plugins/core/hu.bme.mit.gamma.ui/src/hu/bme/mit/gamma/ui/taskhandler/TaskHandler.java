/********************************************************************************
 * Copyright (c) 2019 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.ui.taskhandler;

import static com.google.common.base.Preconditions.checkArgument;

import java.io.File;
import java.io.IOException;
import java.util.logging.Logger;

import org.eclipse.core.resources.IFile;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EObject;

import hu.bme.mit.gamma.dialog.DialogUtil;
import hu.bme.mit.gamma.genmodel.model.AdaptiveContractTestGeneration;
import hu.bme.mit.gamma.genmodel.model.CodeGeneration;
import hu.bme.mit.gamma.genmodel.model.Task;
import hu.bme.mit.gamma.genmodel.model.TestGeneration;
import hu.bme.mit.gamma.genmodel.model.Verification;
import hu.bme.mit.gamma.statechart.language.ui.serializer.StatechartLanguageSerializer;
import hu.bme.mit.gamma.statechart.model.Package;
import hu.bme.mit.gamma.trace.language.ui.serializer.TraceLanguageSerializer;
import hu.bme.mit.gamma.trace.model.ExecutionTrace;
import hu.bme.mit.gamma.util.FileUtil;
import hu.bme.mit.gamma.util.GammaEcoreUtil;

public abstract class TaskHandler {
	
	protected final IFile file;
	
	protected GammaEcoreUtil ecoreUtil = new GammaEcoreUtil();
	protected FileUtil fileUtil = new FileUtil();
	protected Logger logger = Logger.getLogger("GammaLogger");
	protected final String projectLocation;
	protected String targetFolderUri;
	
	public TaskHandler(IFile file) {
		this.file = file;
		// E.g., C:/Users/...
		this.projectLocation = file.getProject().getLocation().toString(); 
	}

	public void setTargetFolder(Task task, String parentFolderUri) {
		checkArgument(task.getTargetFolder().size() <= 1);
		if (task.getTargetFolder().isEmpty()) {
			String targetFolder = null;
			if (task instanceof Verification) {
				targetFolder = "trace";
			}
			else if (task instanceof CodeGeneration) {
				targetFolder = "src-gen";
			}
			else if (task instanceof TestGeneration || task instanceof AdaptiveContractTestGeneration) {
				targetFolder = "test-gen";
			}
			else {
				targetFolder = parentFolderUri.substring(projectLocation.length() + 1);
			}
			task.getTargetFolder().add(targetFolder);
		}
		// Setting the attribute
		targetFolderUri = URI.decode(projectLocation + File.separator + task.getTargetFolder().get(0));
	}
	
	protected String getNameWithoutExtension(String fileName) {
		return fileName.substring(0, fileName.lastIndexOf("."));
	}
	
	protected String getContainingFileName(EObject object) {
		return object.eResource().getURI().lastSegment();
	}
	
	/**
	 * Responsible for saving the given element into a resource file.
	 */
	public void saveModel(EObject rootElem, String parentFolder, String fileName) throws IOException {
		// A Gamma statechart model
		try {
			// Trying to serialize the model
			if (rootElem instanceof Package) {
				serializeStatechart(rootElem, parentFolder, fileName);
			}
			else if (rootElem instanceof ExecutionTrace) { 
				serializeTrace(rootElem, parentFolder, fileName);
			}
		} catch (Exception e) {
			e.printStackTrace();
			DialogUtil.showErrorWithStackTrace("Model cannot be serialized.", e);
			new File(parentFolder + File.separator + fileName).delete();
			// Saving like an EMF model
			String newFileName = fileName.substring(0, fileName.lastIndexOf(".")) + ".gsm";
			ecoreUtil.normalSave(rootElem, parentFolder, newFileName);
		}
	}
	
	private void serializeStatechart(EObject rootElem, String parentFolder, String fileName) throws IOException {
		StatechartLanguageSerializer serializer = new StatechartLanguageSerializer();
		serializer.serialize(rootElem, parentFolder, fileName);
	}
	
	private void serializeTrace(EObject rootElem, String parentFolder, String fileName) throws IOException {
		TraceLanguageSerializer serializer = new TraceLanguageSerializer();
		serializer.serialize(rootElem, parentFolder, fileName);
	}
	
}
