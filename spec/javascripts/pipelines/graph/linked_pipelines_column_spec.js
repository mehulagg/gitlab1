import Vue from 'vue';
import LinkedPipelinesColumn from '~/pipelines/components/graph/linked_pipelines_column.vue';
import mockData from './linked_pipelines_mock_data';

const LinkedPipelinesColumnComponent = Vue.extend(LinkedPipelinesColumn);

describe('Linked Pipelines Column', () => {
  beforeEach(() => {
    this.propsData = {
      columnTitle: 'Upstream',
      linkedPipelines: mockData.triggered,
      graphPosition: 'right',
    };

    this.linkedPipelinesColumn = new LinkedPipelinesColumnComponent({
      propsData: this.propsData,
    }).$mount();
  });

  it('instantiates a defined Vue component', () => {
    expect(this.linkedPipelinesColumn).toBeDefined();
  });

  it('renders the pipeline orientation', () => {
    const titleElement = this.linkedPipelinesColumn.$el.querySelector('.linked-pipelines-column-title');
    expect(titleElement.innerText).toContain(this.propsData.columnTitle);
  });

  it('has the correct number of linked pipeline child components', () => {
    expect(this.linkedPipelinesColumn.$children.length).toBe(this.propsData.linkedPipelines.length);
  });

  it('renders the correct number of linked pipelines', () => {
    const linkedPipelineElements = this.linkedPipelinesColumn.$el.querySelectorAll('.linked-pipeline');
    expect(linkedPipelineElements.length).toBe(this.propsData.linkedPipelines.length);
  });

  describe('flatConnectorClass', () => {
    beforeEach(() => {
      this.flatConnectorClass = this.linkedPipelinesColumn.flatConnectorClass;
    });

    it('should return flat-connector-before for the first job on the right side of the graph', () => {
      expect(this.flatConnectorClass(0)).toBe('flat-connector-before');
    });

    it('should return an empty string for subsequent jobs', () => {
      expect(this.flatConnectorClass(1)).toBeFalsy();
      expect(this.flatConnectorClass(99)).toBeFalsy();
    });
  });
});

