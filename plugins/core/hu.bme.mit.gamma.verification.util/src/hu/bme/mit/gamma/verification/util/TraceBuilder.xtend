/********************************************************************************
 * Copyright (c) 2018-2020 Contributors to the Gamma project
 *
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 *
 * SPDX-License-Identifier: EPL-1.0
 ********************************************************************************/
package hu.bme.mit.gamma.verification.util

import hu.bme.mit.gamma.expression.model.BooleanTypeDefinition
import hu.bme.mit.gamma.expression.model.EnumerationTypeDefinition
import hu.bme.mit.gamma.expression.model.Expression
import hu.bme.mit.gamma.expression.model.ExpressionModelFactory
import hu.bme.mit.gamma.expression.model.FieldAssignment
import hu.bme.mit.gamma.expression.model.IntegerTypeDefinition
import hu.bme.mit.gamma.expression.model.ParameterDeclaration
import hu.bme.mit.gamma.expression.model.RecordLiteralExpression
import hu.bme.mit.gamma.expression.model.Type
import hu.bme.mit.gamma.expression.model.VariableDeclaration
import hu.bme.mit.gamma.expression.util.ExpressionEvaluator
import hu.bme.mit.gamma.expression.util.FieldHierarchy
import hu.bme.mit.gamma.statechart.composite.AsynchronousComponentInstance
import hu.bme.mit.gamma.statechart.composite.SynchronousComponent
import hu.bme.mit.gamma.statechart.composite.SynchronousComponentInstance
import hu.bme.mit.gamma.statechart.interface_.Component
import hu.bme.mit.gamma.statechart.interface_.Event
import hu.bme.mit.gamma.statechart.interface_.Port
import hu.bme.mit.gamma.statechart.statechart.State
import hu.bme.mit.gamma.trace.model.InstanceVariableState
import hu.bme.mit.gamma.trace.model.RaiseEventAct
import hu.bme.mit.gamma.trace.model.Step
import hu.bme.mit.gamma.trace.model.TimeElapse
import hu.bme.mit.gamma.trace.model.TraceModelFactory
import hu.bme.mit.gamma.trace.util.TraceUtil
import java.math.BigInteger

import static extension hu.bme.mit.gamma.expression.derivedfeatures.ExpressionModelDerivedFeatures.*

class TraceBuilder {
	// Singleton
	public static final TraceBuilder INSTANCE = new TraceBuilder
	protected new() {}
	//
	protected final extension ExpressionModelFactory expressionModelFactory = ExpressionModelFactory.eINSTANCE
	protected final extension TraceModelFactory traceFactory = TraceModelFactory.eINSTANCE
	
	protected final extension ExpressionEvaluator expressionEvaluator = ExpressionEvaluator.INSTANCE
	protected final extension TraceUtil traceUtil = TraceUtil.INSTANCE
	
	// In event
	
	def addInEventWithParameter(Step step, Port port, Event event,
			ParameterDeclaration parameter, String value) {
		val type = parameter.type.typeDefinition
		return addInEvent(step, port, event, parameter, type.convertStringToInt(value))
	}
	
	def addInEvent(Step step, Port port, Event event) {
		addInEvent(step, port, event, null, null)		
	}
	
	private def addInEvent(Step step, Port port, Event event,
			ParameterDeclaration parameter, Integer value) {
		val eventRaise = createRaiseEventAct(port, event, parameter, value)
		val originalRaise = step.actions.filter(RaiseEventAct).findFirst[it.isOverWritten(eventRaise)]
		if (originalRaise === null) {
			// This is the first raise
			step.actions += eventRaise
		}
		else if (parameter !== null) {
			// Already a raise has been done, setting this parameter too
			val index = parameter.index
			originalRaise.arguments.set(index, parameter.createParameter(value))
		}
	}
	
	// Time elapse
	
	def addTimeElapse(Step step, Expression elapsedTime) {
		return step.addTimeElapse(elapsedTime.evaluateInteger)
	}
	
	def addTimeElapse(Step step, int elapsedTime) {
		val timeElapseActions = step.actions.filter(TimeElapse)
		if (!timeElapseActions.empty) {
			// A single time elapse action in all steps
			val action = timeElapseActions.head
			val newTime = action.elapsedTime + BigInteger.valueOf(elapsedTime)
			action.elapsedTime = newTime
		}
		else {
			// No time elapses in this step so far
			step.actions += createTimeElapse => [
				it.elapsedTime = BigInteger.valueOf(elapsedTime)
			]
		}
	}
	
	// Schedule
	
	def addScheduling(Step step, AsynchronousComponentInstance instance) {
		step.actions += createInstanceSchedule => [
			it.scheduledInstance = instance
		]
	}
	
	def addReset(Step step) {
		step.actions += createReset
	}
	
	def addComponentScheduling(Step step) {
		step.actions += createComponentSchedule
	}
	
	def scheduleIfSynchronousComponent(Step step, Component component) {
		if (component instanceof SynchronousComponent) {
			step.addComponentScheduling
		}
	}
	
	// Out event
	
	def addOutEvent(Step step, Port port, Event event) {
		addOutEventWithParameter(step, port, event, null, null)
	}
	
	def addOutEventWithStringParameter(Step step, Port port, Event event,
			ParameterDeclaration parameter, String value) {
		val type = parameter.type.typeDefinition
		addOutEventWithParameter(step, port, event, parameter, type.convertStringToInt(value))
	}
	
	def addOutEventWithParameter(Step step, Port port, Event event,
			ParameterDeclaration parameter, Integer value) {
		val eventRaise = createRaiseEventAct(port, event, parameter, value)
		val outEventRaises = step.asserts.filter(RaiseEventAct)
		val originalRaise = outEventRaises.findFirst[it.isOverWritten(eventRaise)]
		if (originalRaise === null) {
			// This is the first raise
			step.asserts += eventRaise
		}
		else if (parameter !== null) {
			// Already a raise has been done, setting this parameter too
			val index = parameter.index
			originalRaise.arguments.set(index, parameter.createParameter(value))
		}
	}
	
	// Instance variables
	
	def addInstanceVariableState(Step step, SynchronousComponentInstance instance,
			VariableDeclaration variable, String value) {
		val type = variable.type.typeDefinition
		val expression = type.createLiteral(value)
		step.addInstanceVariableState(instance, variable, expression)
	}
	
	def addInstanceVariableState(Step step, SynchronousComponentInstance instance,
			VariableDeclaration variable, Expression value) {
		step.asserts += createInstanceVariableState => [
			it.instance = instance
			it.declaration = variable
			it.value = value
		]
	}
	
	// Record instance variables
	def addInstanceVariableState(Step step, SynchronousComponentInstance instance,
			VariableDeclaration variable, FieldHierarchy fieldHierarchy, String value) {
		val literal = step.getRecordLiteral(instance, variable)
		var fieldAssignments = literal.fieldAssignments
		var FieldAssignment fieldAssignment
		for (field : fieldHierarchy.fields) {
			fieldAssignment = fieldAssignments.findFirst[it.reference.declaration === field]
			val fieldValue = fieldAssignment.value
			if (fieldValue instanceof RecordLiteralExpression) {
				fieldAssignments = fieldValue.fieldAssignments
			}
		}
		val declaration = fieldAssignment.reference.declaration
		val type = declaration.typeDefinition
		// Type must be primitive
		val expression = type.createLiteral(value)
		fieldAssignment.value = expression
	}
	
	def getRecordLiteral(Step step, SynchronousComponentInstance instance,
			VariableDeclaration variable) {
		val variableStates = step.asserts.filter(InstanceVariableState)
		val variableState = variableStates.filter[it.instance === instance &&
			it.declaration === variable
		].head
		var RecordLiteralExpression value
		if (variableState === null) {
			// Creating the literal, similar to "getInstance" in singletons
			val recordLiteral = variable.initialValue as RecordLiteralExpression
			step.asserts += createInstanceVariableState => [
				it.instance = instance
				it.declaration = variable
				it.value = recordLiteral
			]
			value = recordLiteral
		}
		else {
			value = variableState.value as RecordLiteralExpression
		}
		return value 
	}
	
	// Instance states
	
	def addInstanceState(Step step, SynchronousComponentInstance instance, State state) {
		step.asserts += createInstanceStateConfiguration => [
			it.instance = instance
			it.state = state
		]
	}
	
	// Raise event act
		
	private def createRaiseEventAct(Port port, Event event, ParameterDeclaration parameter, Integer value) {
		val RaiseEventAct eventRaise = createRaiseEventAct => [
			it.port = port
			it.event = event
		]
		val parameters = event.parameterDeclarations
		for (dummyParameter : parameters) {
			eventRaise.arguments += createFalseExpression
		}
		if (parameter !== null) {
			val index = parameter.index
			eventRaise.arguments.set(index, parameter.createParameter(value))
		}
		return eventRaise
	}
	
	// String and int parsing
	
	def createVariableLiteral(VariableDeclaration variable, Integer value) {
		val type = variable.type.typeDefinition
		return type.createLiteral(value)
	}
	
	private def createParameter(ParameterDeclaration parameter, Integer value) {
		if (parameter === null) {
			return null
		}
		val paramType = parameter.type.typeDefinition
		return paramType.createLiteral(value)
	}
	
	private def convertStringToInt(Type type, String value) {
		switch (value) {
			case "false":
				return 0
			case "true":
				return 1
			default:
				try {
					return Integer.parseInt(value)
				} catch (NumberFormatException e) {
					if (type instanceof EnumerationTypeDefinition) {
						val literals = type.literals
						val literal = literals.findFirst[it.name.equals(value)]
						return literals.indexOf(literal)
					}
					throw new IllegalArgumentException("Not known value: " + value)
				}
		}
	}
	
	private def Expression createLiteral(Type paramType, String value) {
		return paramType.createLiteral(paramType.convertStringToInt(value))
	}
	
	/**
	 * Only primitive types and enums are accepted, type references are not.
	 */
	private def Expression createLiteral(Type paramType, Integer value) {
		val literal = switch (paramType) {
			IntegerTypeDefinition: createIntegerLiteralExpression => [
				it.value = BigInteger.valueOf(value)
			]
			BooleanTypeDefinition: {
				if (value == 0) {
					createFalseExpression
				}
				else {
					createTrueExpression
				}
			}
			EnumerationTypeDefinition:
				return createEnumerationLiteralExpression => [
					it.reference = paramType.literals.get(value)
				]
			default: 
				throw new IllegalArgumentException("Not known type definition: " + paramType)
		}
		return literal
	}
	
}