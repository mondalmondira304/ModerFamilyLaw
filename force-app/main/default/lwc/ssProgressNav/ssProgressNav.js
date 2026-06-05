import { LightningElement, api } from 'lwc';

export default class SsProgressNav extends LightningElement {
  @api steps = [];        // [{ label, subSteps?: [{ label }] }, ...]
  @api activeIndex = 0;   // active main step (0-based)
  @api activeSubIndex;    // active substep within active step (0-based) or undefined

  get computedSteps()  {
    const a = Number(this.activeIndex) || 0;
    const hasActiveSub = this.activeSubIndex !== null && this.activeSubIndex !== undefined;
    const s = hasActiveSub ? Number(this.activeSubIndex) : null;

    return (this.steps || []).map((step, i) => {
      const isActiveStep = i === a;
      const isBefore = i < a;

      const subSteps = (step.subSteps || []).map((sub, j) => {
        const isSubActive = isActiveStep && s === j;
        const isSubBefore = isActiveStep && s !== null && j < s;

        return {
          ...sub,
          index: j,
          containerClass: 'sub-step-container',
          subCircleClass: 'sub-circle' + (isSubActive || isSubBefore ? ' active' : ''),
          subNameClass: 'sub-step-name' + (isSubActive ? ' active' : isSubBefore ? ' done' : '')
        };
      });

      return {
        ...step,
        index: i,
        circleClass: 'circle' + (isActiveStep || isBefore ? ' on' : ''),
        connectorClass: 'connector' + (isBefore ? ' on' : ''),
        stepNameClass: 'step-name' + (isActiveStep ? ' active' : isBefore ? ' done' : ''),
        hasSubSteps: subSteps.length > 0,
        subSteps
      };
    });
  }
}